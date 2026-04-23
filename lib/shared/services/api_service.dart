import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for your PHP API
  static const String baseUrl = 'http://your-server.com/api';

  // AI API configuration (OpenAI-compatible format)
  // Get API key: https://aistudio.google.com/apikey
  static const String aiApiKey = 'YOUR_GEMINI_API_KEY';
  static const String aiModel = 'gemini-2.0-flash';
  static const String aiApiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/openai';
  static const String aiChatCompletionsPath = '/chat/completions';

  // Singleton pattern
  static final ApiService instance = ApiService._init();
  ApiService._init();

  // ==================== AI Analysis API ====================

  bool _isDnsLookupError(Object error) {
    final text = error.toString().toLowerCase();
    return error is SocketException ||
        text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('errno = 7');
  }

  /// Send a request to an OpenAI-compatible chat completions endpoint.
  Future<String> _queryAiChatCompletions({
    required List<Map<String, dynamic>> messages,
    int timeoutSeconds = 120,
  }) async {
    final uri = Uri.parse('$aiApiBaseUrl$aiChatCompletionsPath');

    final bodyMap = <String, dynamic>{
      'model': aiModel,
      'messages': messages,
      'temperature': 0.3,
    };

    final body = jsonEncode(bodyMap);

    debugPrint('[AI] Sending to $uri');
    debugPrint('[AI] Messages count: ${messages.length}');
    debugPrint(
        '[AI] Body preview: ${body.substring(0, body.length.clamp(0, 300))}...');

    late final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $aiApiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(Duration(seconds: timeoutSeconds));
    } catch (e) {
      if (_isDnsLookupError(e)) {
        throw Exception(
          'AI_DNS_LOOKUP_FAILED: Cannot resolve generativelanguage.googleapis.com from this device/emulator. '
          'Check device network/DNS settings or emulator DNS server.',
        );
      }
      rethrow;
    }

    debugPrint('[AI] Response status: ${response.statusCode}');
    debugPrint(
        '[AI] Response body preview: ${response.body.substring(0, response.body.length.clamp(0, 500))}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // OpenAI-compatible response format: choices[0].message.content
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final firstChoice = choices.first;
        final message = firstChoice['message'];
        final content = message?['content'];

        if (content is String && content.trim().isNotEmpty) {
          debugPrint('[AI] AI response length: ${content.length}');
          return content;
        }

        // Some OpenAI-compatible implementations may return structured content.
        if (content is List && content.isNotEmpty) {
          final textParts = content
              .map((part) =>
                  (part is Map ? part['text']?.toString() : null) ?? '')
              .where((text) => text.isNotEmpty)
              .toList();
          final joined = textParts.join('\n').trim();
          debugPrint('[AI] AI response length: ${joined.length}');
          if (joined.isNotEmpty) return joined;
        }
      }

      final errorObj = data['error'];
      if (errorObj is Map && errorObj['message'] != null) {
        throw Exception('AI request failed: ${errorObj['message']}');
      }

      // Fallback to raw response when text cannot be extracted.
      return response.body;
    }

    throw Exception(
        'AI API error: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 300))}');
  }

  /// Extract JSON from AI text output.
  Map<String, dynamic>? _extractJson(String text) {
    // Try direct JSON parsing first.
    try {
      final decoded = jsonDecode(text.trim());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // Try extracting a fenced JSON code block.
    final codeBlockMatch =
        RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```').firstMatch(text);
    if (codeBlockMatch != null) {
      try {
        final decoded = jsonDecode(codeBlockMatch.group(1)!.trim());
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // Try extracting an embedded JSON object.
    final jsonMatch =
        RegExp(r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}').firstMatch(text);
    if (jsonMatch != null) {
      try {
        final decoded = jsonDecode(jsonMatch.group(0)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  /// Analyze a building damage image with AI API.
  Future<Map<String, dynamic>> analyzeImageWithAI(String imageBase64,
      {String? additionalContext}) async {
    try {
      final prompt = StringBuffer();
      prompt.writeln('You are a building safety inspection assistant.');
      prompt.writeln(
          'Analyze the image/context and return JSON only with inferred values.');
      prompt.writeln('{');
      prompt.writeln('  "damage_detected": <boolean>,');
      prompt.writeln('  "damage_types": [<string>, ...],');
      prompt.writeln('  "analysis": <string>,');
      prompt.writeln('  "building_element": <string_or_null>,');
      prompt.writeln('  "defect_type": <string_or_null>,');
      prompt.writeln('  "diagnosis": <string_or_null>,');
      prompt.writeln('  "suspected_cause": <string_or_null>,');
      prompt.writeln('  "recommendation": <string_or_null>,');
      prompt.writeln('  "defect_size": <string_or_null>,');
      prompt.writeln('  "recommendations": [<string>, ...]');
      prompt.writeln('}');
      prompt.writeln('Do not include markdown or extra text.');

      if (additionalContext != null && additionalContext.isNotEmpty) {
        prompt.writeln('Inspector observations and context:');
        prompt.writeln(additionalContext);
      }

      // Build OpenAI-compatible messages payload.
      debugPrint(
          '[AI] Image base64 length: ${imageBase64.length} chars (~${(imageBase64.length * 3 / 4 / 1024).toStringAsFixed(0)} KB)');

      final messages = <Map<String, dynamic>>[];

      // If the image is too large (> 1MB base64 ~ 750KB image), skip image attachment.
      if (imageBase64.length < 1400000) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt.toString()},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$imageBase64',
              },
            },
          ],
        });
      } else {
        debugPrint('[AI] Image too large, sending text-only analysis');
        prompt.writeln(
            '\n(Note: Image too large to attach. Analyze based on user description.)');
        messages.add({
          'role': 'user',
          'content': prompt.toString(),
        });
      }

      // Query AI API.
      final responseText = await _queryAiChatCompletions(messages: messages);

      debugPrint(
          '[AI] Raw response: ${responseText.substring(0, responseText.length.clamp(0, 500))}');

      // Parse response.
      final json = _extractJson(responseText);
      if (json != null) {
        // Ensure required fields exist.
        return {
          'damage_detected': json['damage_detected'] ?? true,
          'damage_types': json['damage_types'] ?? [],
          'analysis': json['analysis'] ?? responseText,
          'building_element': json['building_element'],
          'defect_type': json['defect_type'],
          'diagnosis': json['diagnosis'],
          'suspected_cause': json['suspected_cause'],
          'recommendation': json['recommendation'],
          'defect_size': json['defect_size'],
          'recommendations':
              json['recommendations'] ?? ['Schedule a professional inspection'],
        };
      }

      // If JSON cannot be parsed, use plain text as analysis output.
      debugPrint('[AI] No JSON found, using raw text as analysis');
      return {
        'damage_detected': true,
        'analysis':
            responseText.isNotEmpty ? responseText : 'AI analysis complete',
        'building_element': null,
        'defect_type': null,
        'diagnosis': null,
        'suspected_cause': null,
        'recommendation': null,
        'defect_size': null,
        'recommendations': ['Schedule a professional inspection'],
      };
    } catch (e) {
      debugPrint('[AI] AI Analysis Error: $e');
      if (_isDnsLookupError(e)) {
        final fallbackRecommendations =
            _getRecommendations('moderate', 'structural');
        return {
          'damage_detected': true,
          'analysis':
              'AI API DNS lookup failed on current device. Using local offline assessment.',
          'recommendations': [
            ...fallbackRecommendations,
            'Check device/emulator network DNS for generativelanguage.googleapis.com',
          ],
          'source': 'local_fallback_dns_error',
        };
      }
      rethrow;
    }
  }

  /// Chat with AI API (for follow-up defect questions and supplemental analysis).
  Future<String> chatWithAI({
    required String userMessage,
    String? imageBase64,
    List<Map<String, String>>? chatHistory,
  }) async {
    try {
      const systemPrompt =
          'You are the SmartSurvey building safety AI assistant. Please respond in English.'
          'Your task is to help users analyze building damage and provide maintenance recommendations.'
          'Keep your answers concise and professional.';

      final messages = <Map<String, dynamic>>[];

      // System prompt in OpenAI-compatible format.
      messages.add({
        'role': 'system',
        'content': systemPrompt,
      });

      // Add chat history in OpenAI-compatible format.
      if (chatHistory != null) {
        for (final msg in chatHistory) {
          final originalRole = (msg['role'] ?? 'user').toLowerCase();
          final role = (originalRole == 'assistant' ||
                  originalRole == 'model' ||
                  originalRole == 'bot')
              ? 'assistant'
              : 'user';

          messages.add({
            'role': role,
            'content': msg['content'] ?? '',
          });
        }
      }

      // Current user message.
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': userMessage},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$imageBase64',
              },
            },
          ],
        });
      } else {
        messages.add({
          'role': 'user',
          'content': userMessage,
        });
      }

      // Query AI API.
      final responseText = await _queryAiChatCompletions(messages: messages);

      return responseText.isNotEmpty
          ? responseText
          : 'AI is temporarily unavailable. Please try again later.';
    } catch (e) {
      debugPrint('[AI Chat] Error: $e');
      if (_isDnsLookupError(e)) {
        return 'AI API is unreachable from this device (DNS lookup failed). '
            'Please check network/DNS settings and try again.';
      }
      rethrow;
    }
  }

  static List<String> _getRecommendations(String severity, String category) {
    final List<String> recommendations = [];

    if (severity == 'severe') {
      recommendations.add('Notify relevant departments immediately');
      recommendations.add('Consider temporarily closing the affected area');
      recommendations
          .add('Arrange professional inspection as soon as possible');
    } else if (severity == 'moderate') {
      recommendations.add('Arrange professional inspection');
      recommendations.add('Monitor for further deterioration');
    } else {
      recommendations.add('Monitor the situation periodically');
      recommendations.add('Schedule routine maintenance');
    }

    switch (category) {
      case 'structural':
        recommendations.add('Contact a structural engineer for assessment');
        break;
      case 'exterior':
        recommendations.add('Check exterior wall waterproofing');
        break;
      case 'electrical':
        recommendations.add('Do not touch. Contact an electrician.');
        break;
      case 'plumbing':
        recommendations.add('Shut off the water valve and contact a plumber.');
        break;
    }

    return recommendations;
  }
}
