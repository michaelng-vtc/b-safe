/// UWB positioning system data models.
/// Based on the Aithinker UWB TWR system.
library;

/// Anchor data model.
class UwbAnchor {
  final String id;
  final double x; // X coordinate (meters)
  final double y; // Y coordinate (meters)
  final double z; // Z coordinate / height (meters)
  final bool isActive;

  UwbAnchor({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    this.isActive = true,
  });

  factory UwbAnchor.fromJson(Map<String, dynamic> json) {
    return UwbAnchor(
      id: json['id'] ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      z: (json['z'] ?? 0.0).toDouble(),
      isActive: json['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'z': z,
      'isActive': isActive,
    };
  }

  @override
  String toString() => 'Anchor($id: $x, $y, $z)';
}

/// Tag data model (tracking target).
class UwbTag {
  final String id;
  final double x; // X coordinate (meters)
  final double y; // Y coordinate (meters)
  final double z; // Z coordinate (meters)
  final double r95; // Positioning accuracy
  final Map<String, double> anchorDistances; // Distance to each anchor
  final DateTime timestamp;

  UwbTag({
    required this.id,
    required this.x,
    required this.y,
    required this.z,
    this.r95 = 0.0,
    this.anchorDistances = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory UwbTag.fromJson(Map<String, dynamic> json) {
    final Map<String, double> distances = {};
    if (json['distances'] != null) {
      (json['distances'] as Map<String, dynamic>).forEach((key, value) {
        distances[key] = (value ?? 0.0).toDouble();
      });
    }

    return UwbTag(
      id: json['id'] ?? '',
      x: (json['x'] ?? 0.0).toDouble(),
      y: (json['y'] ?? 0.0).toDouble(),
      z: (json['z'] ?? 0.0).toDouble(),
      r95: (json['r95'] ?? 0.0).toDouble(),
      anchorDistances: distances,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'x': x,
      'y': y,
      'z': z,
      'r95': r95,
      'distances': anchorDistances,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  String toString() => 'Tag($id: $x, $y, $z)';
}

/// UWB system configuration.
class UwbConfig {
  final String positioningMode; // 2D positioning / 3D positioning
  final String algorithm; // Kalman / averaging algorithm
  final double areaRadius1; // Area 1 radius (meters)
  final double areaRadius2; // Area 2 radius (meters)
  final bool showTrajectory; // Show trajectory
  final bool showHistoryTrajectory; // Show trajectory history
  final bool showFence; // Show fence
  final bool
      innerFenceAlarm; // Inner-fence alarm (true) / outer-fence alarm (false)
  final double correctionA; // Distance correction coefficient a
  final double correctionB; // Distance correction coefficient b
  final double gridWidth; // Grid width (meters)
  final double gridHeight; // Grid height (meters)
  final bool showGrid; // Show grid
  final bool showAnchorList; // Show anchor list
  final bool showTagList; // Show tag list
  final bool autoGetAnchorCoords; // Auto-detect anchor coordinates
  final double xOffset; // X offset (pixels)
  final double yOffset; // Y offset (pixels)
  final double xScale; // X scale (pixels per meter)
  final double yScale; // Y scale (pixels per meter)
  final bool flipX; // Flip X
  final bool flipY; // Flip Y
  final bool showOrigin; // Show origin
  final String? floorPlanImagePath; // Floor plan image path
  final bool showFloorPlan; // Show floor plan
  final double floorPlanOpacity; // Floor plan opacity
  final String floorPlanFileType; // Floor plan file type (image/svg/pdf/dwg)
  final List<int>
      distanceIndexMap; // Distance index mapping for D0~D3 to anchors

  UwbConfig({
    this.positioningMode = '2D Positioning',
    this.algorithm = 'Kalman/Average',
    this.areaRadius1 = 2.0,
    this.areaRadius2 = 4.0,
    this.showTrajectory = true,
    this.showHistoryTrajectory = false,
    this.showFence = false,
    this.innerFenceAlarm = true,
    this.correctionA = 0.78,
    this.correctionB = 0.0,
    this.gridWidth = 0.5,
    this.gridHeight = 0.5,
    this.showGrid = true,
    this.showAnchorList = true,
    this.showTagList = true,
    this.autoGetAnchorCoords = false,
    this.xOffset = 0.0,
    this.yOffset = 0.0,
    this.xScale = 50.0,
    this.yScale = 50.0,
    this.flipX = false,
    this.flipY = false,
    this.showOrigin = true,
    this.floorPlanImagePath,
    this.showFloorPlan = false,
    this.floorPlanOpacity = 0.5,
    this.floorPlanFileType = 'image',
    this.distanceIndexMap = const [0, 1, 2, 3],
  });

  UwbConfig copyWith({
    String? positioningMode,
    String? algorithm,
    double? areaRadius1,
    double? areaRadius2,
    bool? showTrajectory,
    bool? showHistoryTrajectory,
    bool? showFence,
    bool? innerFenceAlarm,
    double? correctionA,
    double? correctionB,
    double? gridWidth,
    double? gridHeight,
    bool? showGrid,
    bool? showAnchorList,
    bool? showTagList,
    bool? autoGetAnchorCoords,
    double? xOffset,
    double? yOffset,
    double? xScale,
    double? yScale,
    bool? flipX,
    bool? flipY,
    bool? showOrigin,
    String? floorPlanImagePath,
    bool? showFloorPlan,
    double? floorPlanOpacity,
    String? floorPlanFileType,
    List<int>? distanceIndexMap,
  }) {
    return UwbConfig(
      positioningMode: positioningMode ?? this.positioningMode,
      algorithm: algorithm ?? this.algorithm,
      areaRadius1: areaRadius1 ?? this.areaRadius1,
      areaRadius2: areaRadius2 ?? this.areaRadius2,
      showTrajectory: showTrajectory ?? this.showTrajectory,
      showHistoryTrajectory:
          showHistoryTrajectory ?? this.showHistoryTrajectory,
      showFence: showFence ?? this.showFence,
      innerFenceAlarm: innerFenceAlarm ?? this.innerFenceAlarm,
      correctionA: correctionA ?? this.correctionA,
      correctionB: correctionB ?? this.correctionB,
      gridWidth: gridWidth ?? this.gridWidth,
      gridHeight: gridHeight ?? this.gridHeight,
      showGrid: showGrid ?? this.showGrid,
      showAnchorList: showAnchorList ?? this.showAnchorList,
      showTagList: showTagList ?? this.showTagList,
      autoGetAnchorCoords: autoGetAnchorCoords ?? this.autoGetAnchorCoords,
      xOffset: xOffset ?? this.xOffset,
      yOffset: yOffset ?? this.yOffset,
      xScale: xScale ?? this.xScale,
      yScale: yScale ?? this.yScale,
      flipX: flipX ?? this.flipX,
      flipY: flipY ?? this.flipY,
      showOrigin: showOrigin ?? this.showOrigin,
      floorPlanImagePath: floorPlanImagePath ?? this.floorPlanImagePath,
      showFloorPlan: showFloorPlan ?? this.showFloorPlan,
      floorPlanOpacity: floorPlanOpacity ?? this.floorPlanOpacity,
      floorPlanFileType: floorPlanFileType ?? this.floorPlanFileType,
      distanceIndexMap: distanceIndexMap ?? this.distanceIndexMap,
    );
  }
}

/// Trajectory point.
class TrajectoryPoint {
  final double x;
  final double y;
  final DateTime timestamp;

  TrajectoryPoint({
    required this.x,
    required this.y,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
