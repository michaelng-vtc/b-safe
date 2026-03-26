import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityProvider extends ChangeNotifier {
  bool _isOnline = true;
  bool _manualOfflineMode = false; // Mode.
  late StreamSubscription<ConnectivityResult> _subscription;

  bool get isOnline => _manualOfflineMode ? false : _isOnline;
  bool get isManualOfflineMode => _manualOfflineMode;

  ConnectivityProvider() {
    _initConnectivity();
  }

  void _initConnectivity() {
    // Check initial connectivity
    Connectivity().checkConnectivity().then((result) {
      _updateConnectionStatus([result]);
    });

    // Listen for connectivity changes
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectionStatus([result]);
    });
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && 
                !results.contains(ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      notifyListeners();
    }
  }

  // Count occurrences of detected offset patterns.
  void toggleManualOfflineMode() {
    _manualOfflineMode = !_manualOfflineMode;
    notifyListeners();
  }

  // Count occurrences of detected offset patterns.
  void setManualOfflineMode(bool offline) {
    _manualOfflineMode = offline;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
