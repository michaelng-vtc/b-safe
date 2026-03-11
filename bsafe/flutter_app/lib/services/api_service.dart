import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bsafe_app/models/report_model.dart';

class ApiService {
  // Base URL for your PHP API
  static const String baseUrl = 'http://your-server.com/api';

  // POE API for AI image analysis (OpenAI-compatible endpoint)
  static const String poeApiKey =
      'HTLbuegNjtBmxNX5rWeH7cyxFfNc1oANBPRtdY_aO4E';
  static const String poeBotName = 'B-SAFE';
  static const String poeApiUrl =
      'https://api.poe.com/v1/chat/completions';

  // Singleton pattern
  static final ApiService instance = ApiService._init();
  ApiService._init();

  // Headers for API requests
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // ==================== Report API ====================

  // Submit a new report
  Future<Map<String, dynamic>> submitReport(ReportModel report) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/reports'),
        headers: _headers,
        body: jsonEncode(report.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to submit report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all reports from server
  Future<List<ReportModel>> getReports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/reports'),
        headers: _headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => ReportModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get reports: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update report status
  Future<Map<String, dynamic>> updateReportStatus(int id, String status) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/reports/$id'),
        headers: _headers,
        body: jsonEncode({'status': status}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Sync pending reports
  Future<void> syncReports(List<ReportModel> reports) async {
    for (final report in reports) {
      try {
        await submitReport(report);
      } catch (e) {
        // Log error but continue with other reports
        debugPrint('Failed to sync report ${report.id}: $e');
      }
    }
  }

  // ==================== POE AI Analysis API ====================

  /// 發送訊息給 POE Bot (OpenAI-compatible endpoint)
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
    debugPrint('[POE] Body preview: ${body.substring(0, body.length.clamp(0, 300))}...');

    final response = await http
        .post(
          Uri.parse(poeApiUrl),
          headers: {
            'Authorization': 'Bearer $poeApiKey',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(Duration(seconds: timeoutSeconds));

    debugPrint('[POE] Response status: ${response.statusCode}');
    debugPrint('[POE] Response body preview: ${response.body.substring(0, response.body.length.clamp(0, 500))}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // OpenAI-compatible response format: choices[0].message.content
      if (data is Map && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
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

    throw Exception('POE API error: ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 300))}');
  }

  /// 從 AI 文字回應中提取 JSON
  Map<String, dynamic>? _extractJson(String text) {
    // 嘗試直接解析
    try {
      final decoded = jsonDecode(text.trim());
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    // 嘗試提取 JSON 代碼塊
    final codeBlockMatch =
        RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```').firstMatch(text);
    if (codeBlockMatch != null) {
      try {
        final decoded = jsonDecode(codeBlockMatch.group(1)!.trim());
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    // 嘗試提取嵌入的 JSON 物件
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

  /// 用 POE AI 分析建築物損壞圖片
  Future<Map<String, dynamic>> analyzeImageWithAI(String imageBase64,
      {String? additionalContext}) async {
    try {
      final prompt = StringBuffer();
      prompt.writeln('You are a professional building safety inspection AI assistant (B-SAFE system).');
      prompt.writeln('Please analyze the following building damage and assess the risk.');
      prompt.writeln();
      prompt.writeln('Please perform the following assessment:');
      prompt.writeln('1. Identify damage types (cracks, spalling, corrosion, leaks, deformation, etc.)');
      prompt.writeln('2. Assess damage severity (mild / moderate / severe)');
      prompt.writeln('3. Determine risk level (low / medium / high)');
      prompt.writeln('4. Calculate risk score (0-100)');
      prompt.writeln('5. Whether urgent action is needed (true/false)');
      prompt.writeln('6. Provide recommendations (at least 2)');
      prompt.writeln();
      prompt.writeln('Return in the following JSON format:');
      prompt.writeln('{');
      prompt.writeln('  "damage_detected": true,');
      prompt.writeln('  "damage_types": ["crack", "spalling"],');
      prompt.writeln('  "severity": "moderate",');
      prompt.writeln('  "risk_level": "medium",');
      prompt.writeln('  "risk_score": 65,');
      prompt.writeln('  "is_urgent": false,');
      prompt.writeln('  "analysis": "Moderate damage found...",');
      prompt.writeln('  "recommendations": ["Schedule professional inspection", "Monitor for deterioration"]');
      prompt.writeln('}');
      prompt.writeln();
      prompt.writeln('⚠ IMPORTANT: Return JSON only. No extra text or markdown.');

      if (additionalContext != null && additionalContext.isNotEmpty) {
        prompt.writeln();
        prompt.writeln('Inspector observations and context:');
        prompt.writeln(additionalContext);
        prompt.writeln();
        prompt.writeln('Use the above inspector observations and surrounding defect data to provide a comprehensive, conclusive analysis. Factor in spatial patterns when determining root cause.');
      }

      // 構建訊息（OpenAI-compatible vision format）
      debugPrint('[POE] Image base64 length: ${imageBase64.length} chars (~${(imageBase64.length * 3 / 4 / 1024).toStringAsFixed(0)} KB)');

      final messages = <Map<String, dynamic>>[];

      // 如果圖片太大 (> 1MB base64 ~ 750KB image)，就不附帶圖片
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
        prompt.writeln('\n(Note: Image too large to attach. Analyze based on user description.)');
        messages.add({
          'role': 'user',
          'content': prompt.toString(),
        });
      }

      // 查詢 POE Bot
      final responseText = await _queryPoeBot(messages: messages);

      debugPrint('[POE] Raw response: ${responseText.substring(0, responseText.length.clamp(0, 500))}');

      // 解析回應
      final json = _extractJson(responseText);
      if (json != null) {
        // 確保必要欄位存在
        return {
          'damage_detected': json['damage_detected'] ?? true,
          'damage_types': json['damage_types'] ?? [],
          'severity': json['severity'] ?? 'moderate',
          'risk_level': json['risk_level'] ?? 'medium',
          'risk_score': json['risk_score'] ?? 50,
          'is_urgent': json['is_urgent'] ?? false,
          'analysis': json['analysis'] ?? responseText,
          'recommendations': json['recommendations'] ?? ['Schedule a professional inspection'],
        };
      }

      // 無法解析 JSON，將純文字作為分析結果
      debugPrint('[POE] No JSON found, using raw text as analysis');
      return {
        'damage_detected': true,
        'severity': 'moderate',
        'risk_level': 'medium',
        'risk_score': 50,
        'is_urgent': false,
        'analysis': responseText.isNotEmpty ? responseText : 'AI analysis complete',
        'recommendations': ['Schedule a professional inspection'],
      };
    } catch (e) {
      debugPrint('[POE] AI Analysis Error: $e');
      rethrow;
    }
  }

  /// 與 POE AI 聊天（用於缺陷追問、補充分析）
  Future<String> chatWithAI({
    required String userMessage,
    String? imageBase64,
    List<Map<String, String>>? chatHistory,
  }) async {
    try {
      final messages = <Map<String, dynamic>>[];

      // 系統提示
      messages.add({
        'role': 'system',
        'content':
            'You are the B-SAFE building safety AI assistant. Please respond in English.'
            'Your task is to help users analyze building damage, assess risk, and provide maintenance recommendations.'
            'Keep your answers concise and professional.',
      });

      // 加入歷史對話
      if (chatHistory != null) {
        for (final msg in chatHistory) {
          messages.add({
            'role': msg['role'] ?? 'user',
            'content': msg['content'] ?? '',
          });
        }
      }

      // 當前訊息
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

      // 查詢 POE Bot
      final responseText = await _queryPoeBot(messages: messages);

      return responseText.isNotEmpty ? responseText : 'AI is temporarily unavailable. Please try again later.';
    } catch (e) {
      debugPrint('[POE Chat] Error: $e');
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
      recommendations.add('Arrange professional inspection as soon as possible');
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
