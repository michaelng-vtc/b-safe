class ReportModel {
  final int? id;
  final String title;
  final String description;
  final String category; // structural, exterior, public_area, electrical, plumbing, other
  final String severity; // mild, moderate, severe
  final String riskLevel; // low, medium, high
  final int riskScore; // 0-100
  final bool isUrgent;
  final String status; // pending, in_progress, resolved
  final String? imagePath;
  final String? imageBase64;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? aiAnalysis;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool synced;

  ReportModel({
    this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.severity,
    this.riskLevel = 'low',
    this.riskScore = 0,
    this.isUrgent = false,
    this.status = 'pending',
    this.imagePath,
    this.imageBase64,
    this.location,
    this.latitude,
    this.longitude,
    this.aiAnalysis,
    DateTime? createdAt,
    this.updatedAt,
    this.synced = false,
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'severity': severity,
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'is_urgent': isUrgent ? 1 : 0,
      'status': status,
      'image_path': imagePath,
      'image_base64': imageBase64,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'ai_analysis': aiAnalysis,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'synced': synced ? 1 : 0,
    };
  }

  // Create from database Map
  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String,
      category: map['category'] as String,
      severity: map['severity'] as String,
      riskLevel: map['risk_level'] as String? ?? 'low',
      riskScore: map['risk_score'] as int? ?? 0,
      isUrgent: (map['is_urgent'] as int?) == 1,
      status: map['status'] as String? ?? 'pending',
      imagePath: map['image_path'] as String?,
      imageBase64: map['image_base64'] as String?,
      location: map['location'] as String?,
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      aiAnalysis: map['ai_analysis'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      synced: (map['synced'] as int?) == 1,
    );
  }

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'severity': severity,
      'risk_level': riskLevel,
      'risk_score': riskScore,
      'is_urgent': isUrgent,
      'status': status,
      'image_base64': imageBase64,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'ai_analysis': aiAnalysis,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  // Create from API JSON
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as int?,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      severity: json['severity'] as String,
      riskLevel: json['risk_level'] as String? ?? 'low',
      riskScore: json['risk_score'] as int? ?? 0,
      isUrgent: json['is_urgent'] as bool? ?? false,
      status: json['status'] as String? ?? 'pending',
      imageBase64: json['image_base64'] as String?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      aiAnalysis: json['ai_analysis'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      synced: true,
    );
  }

  // Copy with modifications
  ReportModel copyWith({
    int? id,
    String? title,
    String? description,
    String? category,
    String? severity,
    String? riskLevel,
    int? riskScore,
    bool? isUrgent,
    String? status,
    String? imagePath,
    String? imageBase64,
    String? location,
    double? latitude,
    double? longitude,
    String? aiAnalysis,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? synced,
  }) {
    return ReportModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      riskLevel: riskLevel ?? this.riskLevel,
      riskScore: riskScore ?? this.riskScore,
      isUrgent: isUrgent ?? this.isUrgent,
      status: status ?? this.status,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      synced: synced ?? this.synced,
    );
  }

  // Category labels
  static String getCategoryLabel(String category) {
    switch (category) {
      case 'structural':
        return 'Structural Issues';
      case 'exterior':
        return 'Exterior Wall Issues';
      case 'public_area':
        return 'Public Area';
      case 'electrical':
        return 'Electrical Issues';
      case 'plumbing':
        return 'Plumbing Issues';
      case 'other':
        return 'Other';
      default:
        return category;
    }
  }

  // Severity labels
  static String getSeverityLabel(String severity) {
    switch (severity) {
      case 'mild':
        return 'Mild';
      case 'moderate':
        return 'Moderate';
      case 'severe':
        return 'Severe';
      default:
        return severity;
    }
  }

  // All categories
  static List<Map<String, String>> get categories => [
    {'value': 'structural', 'label': 'Structural Issues', 'icon': '🏗️'},
    {'value': 'exterior', 'label': 'Exterior Wall Issues', 'icon': '🧱'},
    {'value': 'public_area', 'label': 'Public Area', 'icon': '🚪'},
    {'value': 'electrical', 'label': 'Electrical Issues', 'icon': '⚡'},
    {'value': 'plumbing', 'label': 'Plumbing Issues', 'icon': '🚰'},
    {'value': 'other', 'label': 'Other', 'icon': '📋'},
  ];

  // All severities
  static List<Map<String, String>> get severities => [
    {'value': 'mild', 'label': 'Mild'},
    {'value': 'moderate', 'label': 'Moderate'},
    {'value': 'severe', 'label': 'Severe'},
  ];
}
