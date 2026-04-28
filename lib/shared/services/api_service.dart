import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // AI API configuration (OpenAI-compatible format)
  // Get API key: https://aistudio.google.com/apikey
  static const String aiModel = 'gemini-3-flash-preview';
  static const String aiApiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/openai';
  static const String aiChatCompletionsPath = '/chat/completions';
  static const String _localPropertiesAsset = 'local.properties';

  String? _cachedAiApiKey;

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

  Future<String> _resolveAiApiKey() async {
    if (_cachedAiApiKey != null && _cachedAiApiKey!.trim().isNotEmpty) {
      return _cachedAiApiKey!;
    }

    try {
      final raw = await rootBundle.loadString(_localPropertiesAsset);
      for (final line in raw.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

        final match = RegExp(r'^ai\.apiKey\s*=\s*(.*)$').firstMatch(trimmed);
        if (match != null) {
          final resolved = match.group(1)?.trim().replaceAll('"', '') ?? '';
          if (resolved.isNotEmpty) {
            _cachedAiApiKey = resolved;
            return resolved;
          }
        }
      }
    } catch (e) {
      debugPrint('[AI] Failed to read API key from $_localPropertiesAsset: $e');
    }

    throw Exception(
      'AI_API_KEY_MISSING: Add ai.apiKey=... to $_localPropertiesAsset and include it in pubspec.yaml assets.',
    );
  }

  /// Send a request to an OpenAI-compatible chat completions endpoint.
  Future<String> _queryAiChatCompletions({
    required List<Map<String, dynamic>> messages,
    int timeoutSeconds = 120,
  }) async {
    final uri = Uri.parse('$aiApiBaseUrl$aiChatCompletionsPath');
    final aiApiKey = await _resolveAiApiKey();

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
      {String? additionalContext,
      Map<String, dynamic>? metadata,
      String? yoloResultImageBase64}) async {
    try {
      final prompt = StringBuffer();
      prompt.writeln(
          'You are a building defect analysis assistant for SmartSurvey.');
      prompt.writeln('Inspect the original image and the YOLO overlay image.');
      prompt.writeln(
          'Use the provided context and metadata, then return JSON only.');
      prompt.writeln('Write in short, direct sentences.');
      prompt.writeln('Keep the observation to 1-2 concise sentences.');
      prompt.writeln(
          'Keep the cause section concise, combining Hong Kong construction context and defect cause review in 2-3 sentences total.');
      prompt.writeln(
          'Keep recommendations brief and avoid step-by-step wording.');
      prompt.writeln(
          'Focus on external defects, relate them to Hong Kong construction details and weather, and do not mention risk score or risk level.');
      prompt.writeln(
          'Do not include markdown, code fences, headings, or extra commentary.');
      prompt.writeln('{');
      prompt.writeln('  "observation": <string>,');
      prompt.writeln('  "hk_construction_context": <string>,');
      prompt.writeln('  "cause_review": <string>,');
      prompt.writeln('  "recommendations": <string>');
      prompt.writeln('}');

      if (additionalContext != null && additionalContext.isNotEmpty) {
        prompt.writeln('Additional inspector context:');
        prompt.writeln(additionalContext);
      }

      if (metadata != null && metadata.isNotEmpty) {
        prompt.writeln('Structured metadata (JSON):');
        try {
          prompt.writeln(jsonEncode(metadata));
        } catch (_) {
          prompt.writeln(metadata.toString());
        }
      }

      // Build OpenAI-compatible messages payload.
      debugPrint(
          '[AI] Image base64 length: ${imageBase64.length} chars (~${(imageBase64.length * 3 / 4 / 1024).toStringAsFixed(0)} KB)');

      // Debug: print original image base64 preview (or full if small).
      try {
        final previewLen = imageBase64.length < 200 ? imageBase64.length : 200;
        if (imageBase64.length < 1000) {
          debugPrint('[AI][DEBUG] Original image base64 (full): $imageBase64');
        } else {
          debugPrint(
              '[AI][DEBUG] Original image base64 preview (${imageBase64.length} chars): ${imageBase64.substring(0, previewLen)}...');
        }
      } catch (e) {
        debugPrint('[AI][DEBUG] Failed to preview original base64: $e');
      }

      // Debug: print YOLO overlay base64 preview when provided.
      if (yoloResultImageBase64 != null) {
        try {
          final yLen = yoloResultImageBase64.length;
          final yPreview = yLen < 200
              ? yoloResultImageBase64
              : yoloResultImageBase64.substring(0, 200);
          if (yLen < 1000) {
            debugPrint(
                '[AI][DEBUG] YOLO result image base64 (full): $yoloResultImageBase64');
          } else {
            debugPrint(
                '[AI][DEBUG] YOLO result image base64 preview ($yLen chars): $yPreview...');
          }
        } catch (e) {
          debugPrint('[AI][DEBUG] Failed to preview YOLO base64: $e');
        }
      }

      final messages = <Map<String, dynamic>>[];

      // If the image is too large (> 1MB base64 ~ 750KB image), skip image attachment.
      if (imageBase64.length < 1400000) {
        final content = <dynamic>[
          {'type': 'text', 'text': prompt.toString()},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$imageBase64',
            },
          },
        ];

        // If a YOLO result image is provided, include it as an additional image
        if (yoloResultImageBase64 != null &&
            yoloResultImageBase64.isNotEmpty &&
            yoloResultImageBase64.length < 1400000) {
          content.add({
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,$yoloResultImageBase64',
            },
          });
        }

        messages.add({
          'role': 'user',
          'content': content,
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
        final observation = (json['observation'] ?? '').toString().trim();
        final hkContext =
            (json['hk_construction_context'] ?? '').toString().trim();
        final causeReview = (json['cause_review'] ?? '').toString().trim();
        final recommendations =
            (json['recommendations'] ?? '').toString().trim();

        return {
          'observation': observation,
          'hk_construction_context': hkContext,
          'cause_review': causeReview,
          'recommendations': recommendations,
          'analysis': [
            if (observation.isNotEmpty) '1. $observation',
            if (hkContext.isNotEmpty) '2. $hkContext',
            if (causeReview.isNotEmpty) '3. $causeReview',
            if (recommendations.isNotEmpty) '4. $recommendations',
          ].join('\n\n'),
        };
      }

      // If JSON cannot be parsed, use plain text as analysis output.
      debugPrint('[AI] No JSON found, using raw text as analysis');
      return {
        'observation':
            responseText.isNotEmpty ? responseText : 'AI analysis complete',
        'hk_construction_context': '',
        'cause_review': '',
        'recommendations': '',
        'analysis':
            responseText.isNotEmpty ? responseText : 'AI analysis complete',
      };
    } catch (e) {
      debugPrint('[AI] AI Analysis Error: $e');
      if (_isDnsLookupError(e)) {
        return {
          'observation':
              'AI API DNS lookup failed on the current device. Using the available image and metadata for an offline-style summary.',
          'hk_construction_context':
              'Hong Kong buildings are exposed to humid weather, heavy rainfall, and coastal conditions that can accelerate external deterioration.',
          'cause_review':
              'The defect is likely driven by moisture ingress, weathering, or local detail failure around external building elements.',
          'recommendations':
              'Inspect the affected area, check waterproofing and sealing details, and arrange a site assessment if the defect is progressing.',
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
}
