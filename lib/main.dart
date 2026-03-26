import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:bsafe_app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize pdfrx (required for PDF floor plan loading)
  await pdfrxFlutterInitialize();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const App());
}
