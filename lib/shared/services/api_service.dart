import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService {
  // Base URL for your PHP API
  static const String baseUrl = 'http://your-server.com/api';

  // POE API for AI image analysis (OpenAI-compatible endpoint)
  static const String poeApiKey = 'HTLbuegNjtBmxNX5rWeH7cyxFfNc1oANBPRtdY_aO4E';
  static const String poeBotName = 'B-SAFE';
  static const String poeApiUrl = 'https://api.poe.com/v1/chat/completions';

  // Singleton pattern
  static final ApiService instance = ApiService._init();
  ApiService._init();

  // ==================== POE AI Analysis API ====================

  bool _isDnsLookupError(Object error) {
    final text = error.toString().toLowerCase();
    return error is SocketException ||
        text.contains('failed host lookup') ||
        text.contains('no address associated with hostname') ||
        text.contains('errno = 7');
  }

  /// Send a request to the POE bot (OpenAI-compatible endpoint).
  Future<String> _queryPoeBot({
    required List<Map<String, dynamic>> messages,
    int timeoutSeconds = 120,
  }) async {
    final body = jsonEncode({
      'model': poeBotName,
      'messages': messages,
      'temperature': 0.3,
    });

    debugPrint('[POE] Sending to $poeApiUrl');
    debugPrint('[POE] Messages count: ${messages.length}');
    debugPrint(
        '[POE] Body preview: ${body.substring(0, body.length.clamp(0, 300))}...');

    late final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse(poeApiUrl),
            headers: {
              'Authorization': 'Bearer $poeApiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(Duration(seconds: timeoutSeconds));
    } catch (e) {
      if (_isDnsLookupError(e)) {
        throw Exception(
          'POE_DNS_LOOKUP_FAILED: Cannot resolve api.poe.com from this device/emulator. '
          'Check device network/DNS settings or emulator DNS server.',
        );
      }
      rethrow;
    }

    debugPrint('[POE] Response status: ${response.statusCode}');
    debugPrint(
        '[POE] Response body preview: ${response.body.substring(0, response.body.length.clamp(0, 500))}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // OpenAI-compatible response format: choices[0].message.content
      if (data is Map &&
          data['choices'] is List &&
          (data['choices'] as List).isNotEmpty) {
        final choice = data['choices'][0];
        final content = choice['message']?['content'] ?? '';
        debugPrint('[POE] AI response length: ${content.length}');
        return content;
      }
      // Fallback: try direct text/data fields
      if (data is Map) {
        return data['text'] ?? data['data']?.toString() ?? response.body;
      }
      return response.body;
    }

    throw Exception(
        'POE API error: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 300))}');
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

  /// Analyze a building damage image with POE AI.
  Future<Map<String, dynamic>> analyzeImageWithAI(String imageBase64,
      {String? additionalContext}) async {
    try {
      final prompt = StringBuffer();
      prompt.writeln(
          'You are a professional building safety inspection AI assistant (B-SAFE system).');
      prompt.writeln(
          'Please analyze the following building damage and assess the risk.');
      prompt.writeln();
      prompt.writeln('Please perform the following assessment:');
      prompt.writeln(
          '1. Identify damage types (cracks, spalling, corrosion, leaks, deformation, etc.)');
      prompt.writeln('2. Assess damage severity (mild / moderate / severe)');
      prompt.writeln('3. Determine risk level (low / medium / high)');
      prompt.writeln('4. Calculate risk score (0-100)');
      prompt.writeln('5. Whether urgent action is needed (true/false)');
      prompt.writeln('6. Provide recommendations (at least 2)');
      prompt.writeln(
          '7. Return inspector observation fields: Building Element, Defect Type, Diagnosis, Suspected Cause, Recommendation, Defect Size');
      prompt.writeln();
      prompt.writeln(
          'Return in the following JSON schema format (values must be inferred from the image/context, not copied):');
      prompt.writeln('{');
      prompt.writeln('  "damage_detected": <boolean>,');
      prompt.writeln('  "damage_types": [<string>, ...],');
      prompt.writeln('  "severity": "mild|moderate|severe",');
      prompt.writeln('  "risk_level": "low|medium|high",');
      prompt.writeln('  "risk_score": <integer_0_to_100>,');
      prompt.writeln('  "is_urgent": <boolean>,');
      prompt.writeln('  "analysis": <string>,');
      prompt.writeln('  "building_element": <string_or_null>,');
      prompt.writeln('  "defect_type": <string_or_null>,');
      prompt.writeln('  "diagnosis": <string_or_null>,');
      prompt.writeln('  "suspected_cause": <string_or_null>,');
      prompt.writeln('  "recommendation": <string_or_null>,');
      prompt.writeln('  "defect_size": <string_or_null>,');
      prompt.writeln('  "recommendations": [<string>, ...]');
      prompt.writeln('}');
      prompt.writeln();
      prompt
          .writeln('⚠ IMPORTANT: Return JSON only. No extra text or markdown.');
      prompt.writeln(
          '⚠ IMPORTANT: Do NOT reuse any template/example values. Infer every value from the provided image and context.');

      if (additionalContext != null && additionalContext.isNotEmpty) {
        prompt.writeln();
        prompt.writeln('Inspector observations and context:');
        prompt.writeln(additionalContext);
        prompt.writeln();
        prompt.writeln(
            'Use the above inspector observations and surrounding defect data to provide a comprehensive, conclusive analysis. Factor in spatial patterns when determining root cause.');
      }

      // Build messages (OpenAI-compatible vision format).
      debugPrint(
          '[POE] Image base64 length: ${imageBase64.length} chars (~${(imageBase64.length * 3 / 4 / 1024).toStringAsFixed(0)} KB)');

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
        debugPrint('[POE] Image too large, sending text-only analysis');
        prompt.writeln(
            '\n(Note: Image too large to attach. Analyze based on user description.)');
        messages.add({
          'role': 'user',
          'content': prompt.toString(),
        });
      }

      // Query POE bot.
      final responseText = await _queryPoeBot(messages: messages);

      debugPrint(
          '[POE] Raw response: ${responseText.substring(0, responseText.length.clamp(0, 500))}');

      // Parse response.
      final json = _extractJson(responseText);
      if (json != null) {
        // Ensure required fields exist.
        return {
          'damage_detected': json['damage_detected'] ?? true,
          'damage_types': json['damage_types'] ?? [],
          'severity': json['severity'] ?? 'moderate',
          'risk_level': json['risk_level'] ?? 'medium',
          'risk_score': json['risk_score'] ?? 50,
          'is_urgent': json['is_urgent'] ?? false,
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
      debugPrint('[POE] No JSON found, using raw text as analysis');
      return {
        'damage_detected': true,
        'severity': 'moderate',
        'risk_level': 'medium',
        'risk_score': 50,
        'is_urgent': false,
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
      debugPrint('[POE] AI Analysis Error: $e');
      if (_isDnsLookupError(e)) {
        final fallback = localAnalysis('moderate', 'structural');
        return {
          ...fallback,
          'analysis':
              'Poe API DNS lookup failed on current device. Using local offline assessment.',
          'recommendations': [
            ...((fallback['recommendations'] as List<dynamic>)
                .map((e) => e.toString())),
            'Check device/emulator network DNS for api.poe.com',
          ],
          'source': 'local_fallback_dns_error',
        };
      }
      rethrow;
    }
  }

  /// Chat with POE AI (for follow-up defect questions and supplemental analysis).
  Future<String> chatWithAI({
    required String userMessage,
    String? imageBase64,
    List<Map<String, String>>? chatHistory,
  }) async {
    try {
      final messages = <Map<String, dynamic>>[];

      // System prompt.
      messages.add({
        'role': 'system',
        'content':
            'You are the B-SAFE building safety AI assistant. Please respond in English.'
                'Your task is to help users analyze building damage, assess risk, and provide maintenance recommendations.'
                'Keep your answers concise and professional.',
      });

      // Add chat history.
      if (chatHistory != null) {
        for (final msg in chatHistory) {
          messages.add({
            'role': msg['role'] ?? 'user',
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

      // Query POE bot.
      final responseText = await _queryPoeBot(messages: messages);

      return responseText.isNotEmpty
          ? responseText
          : 'AI is temporarily unavailable. Please try again later.';
    } catch (e) {
      debugPrint('[POE Chat] Error: $e');
      if (_isDnsLookupError(e)) {
        return 'Poe API is unreachable from this device (DNS lookup failed). '
            'Please check network/DNS settings and try again.';
      }
      rethrow;
    }
  }

  /// Local fallback analysis when offline or AI unavailable
  static Map<String, dynamic> localAnalysis(String severity, String category) {
    // Simple rule-based assessment
    int riskScore;
    String riskLevel;
    bool isUrgent;

    switch (severity) {
      case 'severe':
        riskScore = 80 + (category == 'structural' ? 15 : 5);
        riskLevel = 'high';
        isUrgent = true;
        break;
      case 'moderate':
        riskScore = 50 + (category == 'structural' ? 20 : 10);
        riskLevel = riskScore >= 70 ? 'high' : 'medium';
        isUrgent = category == 'structural';
        break;
      case 'mild':
      default:
        riskScore = 20 + (category == 'structural' ? 15 : 5);
        riskLevel = 'low';
        isUrgent = false;
    }

    return {
      'damage_detected': true,
      'severity': severity,
      'risk_level': riskLevel,
      'risk_score': riskScore.clamp(0, 100),
      'is_urgent': isUrgent,
      'analysis': 'Local assessment based on user input (offline mode)',
      'recommendations': _getRecommendations(severity, category),
    };
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
