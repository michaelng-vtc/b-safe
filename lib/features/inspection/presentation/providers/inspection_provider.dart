import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:bsafe_app/features/inspection/domain/entities/inspection_model.dart';
import 'package:bsafe_app/shared/services/api_service.dart';

class InspectionProvider extends ChangeNotifier {
  // Inspection.
  InspectionSession? _currentSession;
  InspectionSession? get currentSession => _currentSession;

  // History.
  List<InspectionSession> _sessions = [];
  List<InspectionSession> get sessions => _sessions;

  // Pin.
  InspectionPin? _selectedPin;
  InspectionPin? get selectedPin => _selectedPin;

  // Pin mode.
  bool _isPinMode = false;
  bool get isPinMode => _isPinMode;

  // Load.
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // AI analysis.
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  final ApiService _api = ApiService.instance;
  final Uuid _uuid = const Uuid();

  static const String _sessionsKey = 'inspection_sessions';
  static const String _currentSessionKey = 'current_session_id';

  InspectionProvider() {
    loadSessions();
  }

  // Translated legacy comment.

  /// Inspection.
  Future<InspectionSession> createSession(String name,
      {String? floorPlanPath, String? projectId, int floor = 1}) async {
    final initialFloorPlans = floorPlanPath != null
        ? [FloorPlanSegment(path: floorPlanPath, order: 1)]
        : const <FloorPlanSegment>[];

    final session = InspectionSession(
      id: _uuid.v4(),
      name: name,
      projectId: projectId,
      floor: floor,
      floorPlanPath: floorPlanPath,
      floorPlans: initialFloorPlans,
      selectedFloorPlanOrder:
          floorPlanPath != null ? initialFloorPlans.first.order : null,
    );

    _currentSession = session;
    _sessions.insert(0, session);
    await _saveSessions();
    notifyListeners();
    return session;
  }

  /// Load.
  Future<void> loadSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getString(_sessionsKey);

      if (sessionsJson != null && sessionsJson.isNotEmpty) {
        final List<dynamic> list = jsonDecode(sessionsJson);
        _sessions = list
            .map((e) => InspectionSession.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Translated legacy note.
      final currentId = prefs.getString(_currentSessionKey);
      if (currentId != null && _sessions.isNotEmpty) {
        _currentSession = _sessions.firstWhere(
          (s) => s.id == currentId,
          orElse: () => _sessions.first,
        );
      }
    } catch (e) {
      debugPrint('Failed to load inspection session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save.
  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_sessions.map((s) => s.toJson()).toList());
      await prefs.setString(_sessionsKey, json);

      if (_currentSession != null) {
        await prefs.setString(_currentSessionKey, _currentSession!.id);
      }
    } catch (e) {
      debugPrint('Failed to save inspection session: $e');
    }
  }

  /// Translated legacy note.
  void switchSession(String sessionId) {
    _currentSession = _sessions.firstWhere(
      (s) => s.id == sessionId,
      orElse: () => _sessions.first,
    );
    _selectedPin = null;
    _saveSessions();
    notifyListeners();
  }

  /// Translated legacy note.
  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_currentSession?.id == sessionId) {
      _currentSession = _sessions.isNotEmpty ? _sessions.first : null;
    }
    await _saveSessions();
    notifyListeners();
  }

  Future<void> removeProjectFloor(String projectId, int floor) async {
    _sessions = _sessions
        .where((session) =>
            !(session.projectId == projectId && session.floor == floor))
        .map((session) {
      if (session.projectId == projectId && session.floor > floor) {
        return session.copyWith(
          floor: session.floor - 1,
          updatedAt: DateTime.now(),
        );
      }
      return session;
    }).toList();

    if (_currentSession != null && _currentSession!.projectId == projectId) {
      if (_currentSession!.floor == floor) {
        final fallback = _sessions.where((s) => s.projectId == projectId);
        _currentSession = fallback.isNotEmpty ? fallback.first : null;
      } else if (_currentSession!.floor > floor) {
        _currentSession = _currentSession!.copyWith(
          floor: _currentSession!.floor - 1,
          updatedAt: DateTime.now(),
        );
        _updateSessionInList();
      } else {
        final idx = _sessions.indexWhere((s) => s.id == _currentSession!.id);
        if (idx >= 0) {
          _currentSession = _sessions[idx];
        }
      }
    }

    await _saveSessions();
    notifyListeners();
  }

  /// Update floor plan path.
  void updateFloorPlan(String path, {int? order}) {
    if (_currentSession == null) return;
    final existingPlans =
        List<FloorPlanSegment>.from(_currentSession!.floorPlans);
    final existingPins = List<InspectionPin>.from(_currentSession!.pins);
    final normalizedOrder = order ??
        (existingPlans.isEmpty
            ? 1
            : (existingPlans
                    .map((e) => e.order)
                    .reduce((a, b) => a > b ? a : b) +
                1));

    final idx = existingPlans.indexWhere((p) => p.order == normalizedOrder);
    if (idx >= 0) {
      existingPlans[idx] = existingPlans[idx].copyWith(path: path);
    } else {
      existingPlans.add(FloorPlanSegment(path: path, order: normalizedOrder));
      existingPlans.sort((a, b) => a.order.compareTo(b.order));
    }

    final migratedPins = existingPins.map((pin) {
      if (pin.floorPlanOrder == null) {
        return pin.copyWith(floorPlanOrder: normalizedOrder);
      }
      return pin;
    }).toList();

    _currentSession = _currentSession!.copyWith(
      floorPlanPath: path,
      floorPlans: existingPlans,
      selectedFloorPlanOrder: normalizedOrder,
      pins: migratedPins,
      updatedAt: DateTime.now(),
    );
    _updateSessionInList();
    _saveSessions();
    notifyListeners();
  }

  void selectFloorPlanOrder(int order) {
    if (_currentSession == null) return;
    final selectedPlan = _currentSession!.floorPlans
        .where((segment) => segment.order == order)
        .cast<FloorPlanSegment?>()
        .firstWhere((segment) => segment != null, orElse: () => null);
    if (selectedPlan == null) return;

    final migratedPins = _currentSession!.pins.map((pin) {
      if (pin.floorPlanOrder == null) {
        return pin.copyWith(floorPlanOrder: order);
      }
      return pin;
    }).toList();

    _currentSession = _currentSession!.copyWith(
      floorPlanPath: selectedPlan.path,
      selectedFloorPlanOrder: order,
      pins: migratedPins,
      updatedAt: DateTime.now(),
    );
    if (_selectedPin != null && _selectedPin!.floorPlanOrder != order) {
      _selectedPin = null;
    }
    _updateSessionInList();
    _saveSessions();
    notifyListeners();
  }

  bool deleteFloorPlanSegment(int order) {
    if (_currentSession == null) return false;

    final plans = List<FloorPlanSegment>.from(_currentSession!.floorPlans);
    final removeIndex = plans.indexWhere((segment) => segment.order == order);
    if (removeIndex < 0) return false;

    plans.removeAt(removeIndex);
    final updatedPins = _currentSession!.pins
        .where((pin) => pin.floorPlanOrder != order)
        .toList();

    int? nextSelectedOrder;
    String? nextFloorPlanPath;

    if (plans.isNotEmpty) {
      plans.sort((a, b) => a.order.compareTo(b.order));
      final fallbackIndex = removeIndex.clamp(0, plans.length - 1);
      final selected = plans[fallbackIndex];
      nextSelectedOrder = selected.order;
      nextFloorPlanPath = selected.path;
    }

    _currentSession = _currentSession!.copyWith(
      floorPlans: plans,
      floorPlanPath: nextFloorPlanPath,
      selectedFloorPlanOrder: nextSelectedOrder,
      pins: updatedPins,
      updatedAt: DateTime.now(),
    );
    if (_selectedPin != null && _selectedPin!.floorPlanOrder == order) {
      _selectedPin = null;
    }

    _updateSessionInList();
    _saveSessions();
    notifyListeners();
    return true;
  }

  // ===== Pin =====.

  /// Pin mode.
  void togglePinMode() {
    _isPinMode = !_isPinMode;
    if (_isPinMode) {
      _selectedPin = null;
    }
    notifyListeners();
  }

  /// Pin mode.
  void disablePinMode() {
    _isPinMode = false;
    notifyListeners();
  }

  /// Pin.
  InspectionPin addPin(double x, double y) {
    if (_currentSession == null) {
      createSession('Inspection ${DateTime.now().toString().substring(0, 16)}');
    }

    final pin = InspectionPin(
      id: _uuid.v4(),
      x: x,
      y: y,
      floorPlanOrder: _currentSession?.selectedFloorPlanOrder,
    );

    final updatedPins = List<InspectionPin>.from(_currentSession!.pins)
      ..add(pin);

    _currentSession = _currentSession!.copyWith(
      pins: updatedPins,
      updatedAt: DateTime.now(),
    );
    _selectedPin = pin;
    _isPinMode = false;
    _updateSessionInList();
    _saveSessions();
    notifyListeners();
    return pin;
  }

  /// Update pin( photo+AIanalysis).
  void updatePin(InspectionPin updatedPin) {
    if (_currentSession == null) return;

    final pins = List<InspectionPin>.from(_currentSession!.pins);
    final index = pins.indexWhere((p) => p.id == updatedPin.id);
    if (index >= 0) {
      pins[index] = updatedPin;
      _currentSession = _currentSession!.copyWith(
        pins: pins,
        updatedAt: DateTime.now(),
      );
      if (_selectedPin?.id == updatedPin.id) {
        _selectedPin = updatedPin;
      }
      _updateSessionInList();
      _saveSessions();
      notifyListeners();
    }
  }

  /// Pin.
  void removePin(String pinId) {
    if (_currentSession == null) return;

    final pins = List<InspectionPin>.from(_currentSession!.pins)
      ..removeWhere((p) => p.id == pinId);

    _currentSession = _currentSession!.copyWith(
      pins: pins,
      updatedAt: DateTime.now(),
    );
    if (_selectedPin?.id == pinId) {
      _selectedPin = null;
    }
    _updateSessionInList();
    _saveSessions();
    notifyListeners();
  }

  /// Pin.
  void selectPin(InspectionPin? pin) {
    _selectedPin = pin;
    notifyListeners();
  }

  /// Translated legacy note.
  void deselectPin() {
    _selectedPin = null;
    notifyListeners();
  }

  // ===== AI analysis =====.

  /// Pin AI analysis.
  Future<InspectionPin> analyzePin(
    InspectionPin pin, {
    required String imageBase64,
    String? imagePath,
  }) async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      Map<String, dynamic> analysis;

      try {
        analysis = await _api.analyzeImageWithAI(imageBase64);
        debugPrint('[InspectionProvider] POE AI analysis success');
      } catch (e) {
        // Analysis.
        debugPrint(
            '[InspectionProvider] POE AI analysis failed, using local fallback: $e');
        analysis = ApiService.localAnalysis('moderate', 'structural');
      }

      final updatedPin = pin.copyWith(
        imagePath: imagePath,
        imageBase64: imageBase64,
        aiResult: analysis,
        category: analysis['category'] as String?,
        severity: analysis['severity'] as String?,
        riskScore: analysis['risk_score'] as int? ?? 50,
        riskLevel: analysis['risk_level'] as String? ?? 'medium',
        description: analysis['analysis'] as String?,
        recommendations: (analysis['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: 'analyzed',
      );

      updatePin(updatedPin);
      return updatedPin;
    } catch (e) {
      debugPrint('AI analysis failed: $e');
      // Analysis pin.
      final fallbackPin = pin.copyWith(
        imagePath: imagePath,
        imageBase64: imageBase64,
        riskScore: 50,
        riskLevel: 'medium',
        description:
            'AI analysis service temporarily unavailable. Using local assessment.',
        recommendations: ['Recommend professional inspection'],
        status: 'analyzed',
      );
      updatePin(fallbackPin);
      return fallbackPin;
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Analysis defect( ).
  Future<Defect> analyzeDefect(
    Defect defect, {
    required String imageBase64,
    String? imagePath,
    String? chatContext,
  }) async {
    _isAnalyzing = true;
    notifyListeners();

    try {
      Map<String, dynamic> analysis;

      try {
        analysis = await _api.analyzeImageWithAI(
          imageBase64,
          additionalContext: chatContext,
        );
      } catch (e) {
        analysis = ApiService.localAnalysis('moderate', 'structural');
      }

      final chatMessages = List<ChatMessage>.from(defect.chatMessages);
      // Add AI response as chat message
      chatMessages.add(ChatMessage(
        id: _uuid.v4(),
        role: 'ai',
        content: analysis['analysis'] as String? ?? 'Analysis complete.',
      ));

      return defect.copyWith(
        imagePath: imagePath ?? defect.imagePath,
        imageBase64: imageBase64,
        aiResult: analysis,
        category: analysis['category'] as String?,
        severity: analysis['severity'] as String?,
        riskScore: analysis['risk_score'] as int? ?? 50,
        riskLevel: analysis['risk_level'] as String? ?? 'medium',
        description: analysis['analysis'] as String?,
        recommendations: (analysis['recommendations'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        status: 'analyzed',
        chatMessages: chatMessages,
      );
    } catch (e) {
      debugPrint('AI defect analysis failed: $e');
      return defect.copyWith(
        imagePath: imagePath ?? defect.imagePath,
        imageBase64: imageBase64,
        riskScore: 50,
        riskLevel: 'medium',
        description:
            'AI analysis service temporarily unavailable. Using local assessment.',
        recommendations: ['Recommend professional inspection'],
        status: 'analyzed',
      );
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  // Translated legacy comment.

  /// Update sessions session.
  void _updateSessionInList() {
    if (_currentSession == null) return;

    final index = _sessions.indexWhere((s) => s.id == _currentSession!.id);
    if (index >= 0) {
      _sessions[index] = _currentSession!;
    }
  }

  /// Inspection.
  Future<void> completeSession() async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      status: 'completed',
      updatedAt: DateTime.now(),
    );
    _updateSessionInList();
    await _saveSessions();
    notifyListeners();
  }

  /// Translated legacy note.
  Future<void> markExported() async {
    if (_currentSession == null) return;

    _currentSession = _currentSession!.copyWith(
      status: 'exported',
      updatedAt: DateTime.now(),
    );
    _updateSessionInList();
    await _saveSessions();
    notifyListeners();
  }

  /// Pins ( ).
  List<InspectionPin> get currentPins {
    final session = _currentSession;
    if (session == null) return [];

    final selectedOrder = session.selectedFloorPlanOrder;
    if (selectedOrder == null) {
      return session.pins.where((pin) => pin.floorPlanOrder == null).toList();
    }

    return session.pins
        .where((pin) => pin.floorPlanOrder == selectedOrder)
        .toList();
  }

  List<FloorPlanSegment> get currentFloorPlans =>
      _currentSession?.floorPlans ?? const [];

  int? get selectedFloorPlanOrder => _currentSession?.selectedFloorPlanOrder;
}
