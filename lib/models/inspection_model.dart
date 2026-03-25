/// AI chat message.
class ChatMessage {
  final String id;
  final String role; // 'user' or 'ai'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        role: json['role'] as String? ?? 'user',
        content: json['content'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}

/// Single defect record with photo, AI results, and chat history.
class Defect {
  final String id;
  final String? imagePath;
  final String? imageBase64;
  final Map<String, dynamic>? aiResult;
  final String? category;
  final String? severity;
  final int riskScore;
  final String riskLevel; // low / medium / high
  final String? description;
  final List<String> recommendations;
  final String status; // pending / analyzed / reviewed
  final List<ChatMessage> chatMessages; // AI chat history
  final DateTime createdAt;
  // Structured input fields for AI analysis
  final String? buildingElement;
  final String? defectType;
  final String? diagnosis;
  final String? suspectedCause;
  final String? recommendation; // user-input single recommendation
  final String? defectSize;
  // Additional information form fields
  final String? extentOfDefect; // 'locally' or 'generally'
  final String? currentUse;
  final String? designedUse;
  final bool? onlyTypicalFloor;
  final String? useOfAbove;
  final bool? adjacentWetArea;
  final bool? adjacentExternalWall;
  final bool? concealedPipeworks;
  final String? repetitivePattern;
  final bool? heavyLoadingAbove;
  final String? remarks;

  Defect({
    required this.id,
    this.imagePath,
    this.imageBase64,
    this.aiResult,
    this.category,
    this.severity,
    this.riskScore = 0,
    this.riskLevel = 'low',
    this.description,
    this.recommendations = const [],
    this.status = 'pending',
    this.chatMessages = const [],
    DateTime? createdAt,
    this.buildingElement,
    this.defectType,
    this.diagnosis,
    this.suspectedCause,
    this.recommendation,
    this.defectSize,
    this.extentOfDefect,
    this.currentUse,
    this.designedUse,
    this.onlyTypicalFloor,
    this.useOfAbove,
    this.adjacentWetArea,
    this.adjacentExternalWall,
    this.concealedPipeworks,
    this.repetitivePattern,
    this.heavyLoadingAbove,
    this.remarks,
  }) : createdAt = createdAt ?? DateTime.now();

  Defect copyWith({
    String? id,
    String? imagePath,
    String? imageBase64,
    Map<String, dynamic>? aiResult,
    String? category,
    String? severity,
    int? riskScore,
    String? riskLevel,
    String? description,
    List<String>? recommendations,
    String? status,
    List<ChatMessage>? chatMessages,
    DateTime? createdAt,
    String? buildingElement,
    String? defectType,
    String? diagnosis,
    String? suspectedCause,
    String? recommendation,
    String? defectSize,
    String? extentOfDefect,
    String? currentUse,
    String? designedUse,
    bool? onlyTypicalFloor,
    String? useOfAbove,
    bool? adjacentWetArea,
    bool? adjacentExternalWall,
    bool? concealedPipeworks,
    String? repetitivePattern,
    bool? heavyLoadingAbove,
    String? remarks,
  }) {
    return Defect(
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      aiResult: aiResult ?? this.aiResult,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      description: description ?? this.description,
      recommendations: recommendations ?? this.recommendations,
      status: status ?? this.status,
      chatMessages: chatMessages ?? this.chatMessages,
      createdAt: createdAt ?? this.createdAt,
      buildingElement: buildingElement ?? this.buildingElement,
      defectType: defectType ?? this.defectType,
      diagnosis: diagnosis ?? this.diagnosis,
      suspectedCause: suspectedCause ?? this.suspectedCause,
      recommendation: recommendation ?? this.recommendation,
      defectSize: defectSize ?? this.defectSize,
      extentOfDefect: extentOfDefect ?? this.extentOfDefect,
      currentUse: currentUse ?? this.currentUse,
      designedUse: designedUse ?? this.designedUse,
      onlyTypicalFloor: onlyTypicalFloor ?? this.onlyTypicalFloor,
      useOfAbove: useOfAbove ?? this.useOfAbove,
      adjacentWetArea: adjacentWetArea ?? this.adjacentWetArea,
      adjacentExternalWall: adjacentExternalWall ?? this.adjacentExternalWall,
      concealedPipeworks: concealedPipeworks ?? this.concealedPipeworks,
      repetitivePattern: repetitivePattern ?? this.repetitivePattern,
      heavyLoadingAbove: heavyLoadingAbove ?? this.heavyLoadingAbove,
      remarks: remarks ?? this.remarks,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'imagePath': imagePath,
        'imageBase64': imageBase64,
        'aiResult': aiResult,
        'category': category,
        'severity': severity,
        'riskScore': riskScore,
        'riskLevel': riskLevel,
        'description': description,
        'recommendations': recommendations,
        'status': status,
        'chatMessages': chatMessages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'buildingElement': buildingElement,
        'defectType': defectType,
        'diagnosis': diagnosis,
        'suspectedCause': suspectedCause,
        'recommendation': recommendation,
        'defectSize': defectSize,
        'extentOfDefect': extentOfDefect,
        'currentUse': currentUse,
        'designedUse': designedUse,
        'onlyTypicalFloor': onlyTypicalFloor,
        'useOfAbove': useOfAbove,
        'adjacentWetArea': adjacentWetArea,
        'adjacentExternalWall': adjacentExternalWall,
        'concealedPipeworks': concealedPipeworks,
        'repetitivePattern': repetitivePattern,
        'heavyLoadingAbove': heavyLoadingAbove,
        'remarks': remarks,
      };

  factory Defect.fromJson(Map<String, dynamic> json) => Defect(
        id: json['id'] as String? ?? '',
        imagePath: json['imagePath'] as String?,
        imageBase64: json['imageBase64'] as String?,
        aiResult: json['aiResult'] as Map<String, dynamic>?,
        category: json['category'] as String?,
        severity: json['severity'] as String?,
        riskScore: json['riskScore'] as int? ?? 0,
        riskLevel: json['riskLevel'] as String? ?? 'low',
        description: json['description'] as String?,
        recommendations: (json['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: json['status'] as String? ?? 'pending',
        chatMessages: (json['chatMessages'] as List<dynamic>?)
                ?.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        buildingElement: json['buildingElement'] as String?,
        defectType: json['defectType'] as String?,
        diagnosis: json['diagnosis'] as String?,
        suspectedCause: json['suspectedCause'] as String?,
        recommendation: json['recommendation'] as String?,
        defectSize: json['defectSize'] as String?,
        extentOfDefect: json['extentOfDefect'] as String?,
        currentUse: json['currentUse'] as String?,
        designedUse: json['designedUse'] as String?,
        onlyTypicalFloor: json['onlyTypicalFloor'] as bool?,
        useOfAbove: json['useOfAbove'] as String?,
        adjacentWetArea: json['adjacentWetArea'] as bool?,
        adjacentExternalWall: json['adjacentExternalWall'] as bool?,
        concealedPipeworks: json['concealedPipeworks'] as bool?,
        repetitivePattern: json['repetitivePattern'] as String?,
        heavyLoadingAbove: json['heavyLoadingAbove'] as bool?,
        remarks: json['remarks'] as String?,
      );

  bool get isAnalyzed => status == 'analyzed' || status == 'reviewed';

  String get riskLevelLabel {
    switch (riskLevel) {
      case 'high':
        return 'High Risk';
      case 'medium':
        return 'Medium Risk';
      case 'low':
        return 'Low Risk';
      default:
        return 'Not Assessed';
    }
  }
}

/// Inspection pin model for markers on the floor plan.
class InspectionPin {
  final String id;
  final double x; // UWB X coordinate (meters)
  final double y; // UWB Y coordinate (meters)
  final List<Defect> defects; // Multiple defect records
  // Legacy fields for backward compatibility
  final String? imagePath; // Captured photo path
  final String? imageBase64; // Photo Base64 data
  final Map<String, dynamic>? aiResult; // AI analysis result
  final String? category; // Defect category
  final String? severity; // Severity level
  final int riskScore; // Risk score 0-100
  final String riskLevel; // low / medium / high
  final String? description; // AI analysis description
  final List<String> recommendations; // Recommended actions
  final String status; // pending / analyzed / reviewed
  final DateTime createdAt;
  final String? note; // User note

  InspectionPin({
    required this.id,
    required this.x,
    required this.y,
    this.defects = const [],
    this.imagePath,
    this.imageBase64,
    this.aiResult,
    this.category,
    this.severity,
    this.riskScore = 0,
    this.riskLevel = 'low',
    this.description,
    this.recommendations = const [],
    this.status = 'pending',
    DateTime? createdAt,
    this.note,
  }) : createdAt = createdAt ?? DateTime.now();

  InspectionPin copyWith({
    String? id,
    double? x,
    double? y,
    List<Defect>? defects,
    String? imagePath,
    String? imageBase64,
    Map<String, dynamic>? aiResult,
    String? category,
    String? severity,
    int? riskScore,
    String? riskLevel,
    String? description,
    List<String>? recommendations,
    String? status,
    DateTime? createdAt,
    String? note,
  }) {
    return InspectionPin(
      id: id ?? this.id,
      x: x ?? this.x,
      y: y ?? this.y,
      defects: defects ?? this.defects,
      imagePath: imagePath ?? this.imagePath,
      imageBase64: imageBase64 ?? this.imageBase64,
      aiResult: aiResult ?? this.aiResult,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      riskScore: riskScore ?? this.riskScore,
      riskLevel: riskLevel ?? this.riskLevel,
      description: description ?? this.description,
      recommendations: recommendations ?? this.recommendations,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'defects': defects.map((d) => d.toJson()).toList(),
      'imagePath': imagePath,
      'imageBase64': imageBase64,
      'aiResult': aiResult,
      'category': category,
      'severity': severity,
      'riskScore': riskScore,
      'riskLevel': riskLevel,
      'description': description,
      'recommendations': recommendations,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
    };
  }

  factory InspectionPin.fromJson(Map<String, dynamic> json) {
    return InspectionPin(
      id: json['id'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
      defects: (json['defects'] as List<dynamic>?)
              ?.map((e) => Defect.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      imagePath: json['imagePath'] as String?,
      imageBase64: json['imageBase64'] as String?,
      aiResult: json['aiResult'] as Map<String, dynamic>?,
      category: json['category'] as String?,
      severity: json['severity'] as String?,
      riskScore: json['riskScore'] as int? ?? 0,
      riskLevel: json['riskLevel'] as String? ?? 'low',
      description: json['description'] as String?,
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      note: json['note'] as String?,
    );
  }

  /// Risk level display
  String get riskLevelLabel {
    switch (riskLevel) {
      case 'high':
        return 'High Risk';
      case 'medium':
        return 'Medium Risk';
      case 'low':
        return 'Low Risk';
      default:
        return 'Not Assessed';
    }
  }

  /// Status display
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'analyzed':
        return 'Analyzed';
      case 'reviewed':
        return 'Reviewed';
      default:
        return status;
    }
  }

  /// Whether analysis is completed.
  bool get isAnalyzed => status == 'analyzed' || status == 'reviewed';

  /// Highest risk score among all defects.
  int get maxDefectRiskScore {
    if (defects.isEmpty) return riskScore;
    final scores = defects.map((d) => d.riskScore).toList();
    if (riskScore > 0) scores.add(riskScore);
    return scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
  }

  /// Highest risk level among all defects.
  String get maxDefectRiskLevel {
    if (defects.isEmpty) return riskLevel;
    const order = {'high': 3, 'medium': 2, 'low': 1};
    String maxLevel = riskLevel;
    int maxOrder = order[riskLevel] ?? 0;
    for (final d in defects) {
      final o = order[d.riskLevel] ?? 0;
      if (o > maxOrder) {
        maxOrder = o;
        maxLevel = d.riskLevel;
      }
    }
    return maxLevel;
  }

  /// Total number of defects.
  int get defectCount => defects.length;

  /// Whether any defect has been analyzed.
  bool get hasAnalyzedDefects => defects.any((d) => d.isAnalyzed);
}

/// Inspection session for a complete floor inspection.
class InspectionSession {
  final String id;
  final String name;
  final String? projectId; // Parent project ID
  final int floor; // Floor number (1-based)
  final String? floorPlanPath;
  final List<InspectionPin> pins;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String status; // active / completed / exported

  InspectionSession({
    required this.id,
    required this.name,
    this.projectId,
    this.floor = 1,
    this.floorPlanPath,
    this.pins = const [],
    DateTime? createdAt,
    this.updatedAt,
    this.status = 'active',
  }) : createdAt = createdAt ?? DateTime.now();

  InspectionSession copyWith({
    String? id,
    String? name,
    String? projectId,
    int? floor,
    String? floorPlanPath,
    List<InspectionPin>? pins,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? status,
  }) {
    return InspectionSession(
      id: id ?? this.id,
      name: name ?? this.name,
      projectId: projectId ?? this.projectId,
      floor: floor ?? this.floor,
      floorPlanPath: floorPlanPath ?? this.floorPlanPath,
      pins: pins ?? this.pins,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'projectId': projectId,
      'floor': floor,
      'floorPlanPath': floorPlanPath,
      'pins': pins.map((p) => p.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'status': status,
    };
  }

  factory InspectionSession.fromJson(Map<String, dynamic> json) {
    return InspectionSession(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed',
      projectId: json['projectId'] as String?,
      floor: json['floor'] as int? ?? 1,
      floorPlanPath: json['floorPlanPath'] as String?,
      pins: (json['pins'] as List<dynamic>?)
              ?.map((e) => InspectionPin.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      status: json['status'] as String? ?? 'active',
    );
  }

  /// Total number of pins.
  int get totalPins => pins.length;

  /// Number of analyzed pins.
  int get analyzedPins => pins.where((p) => p.isAnalyzed).length;

  /// Number of high-risk pins.
  int get highRiskPins => pins.where((p) => p.riskLevel == 'high').length;

  /// Flattened list of all defects.
  List<Defect> get allDefects => pins.expand((p) => p.defects).toList();

  /// Number of low-risk defects.
  int get lowRiskDefects =>
      allDefects.where((d) => d.riskLevel == 'low').length;

  /// Number of medium-risk defects.
  int get mediumRiskDefects =>
      allDefects.where((d) => d.riskLevel == 'medium').length;

  /// Number of high-risk defects.
  int get highRiskDefects =>
      allDefects.where((d) => d.riskLevel == 'high').length;

  /// Average risk score.
  double get averageRiskScore {
    if (pins.isEmpty) return 0;
    final analyzed = pins.where((p) => p.isAnalyzed).toList();
    if (analyzed.isEmpty) return 0;
    return analyzed.map((p) => p.riskScore).reduce((a, b) => a + b) /
        analyzed.length;
  }
}
