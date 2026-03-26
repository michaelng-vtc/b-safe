import 'package:flutter/material.dart';

class MainLayoutController extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex == index) return;
    _currentIndex = index;
    notifyListeners();
  }

  void goToHome() => setIndex(0);
  void goToMonitor() => setIndex(1);
  void goToSettings() => setIndex(2);
}
