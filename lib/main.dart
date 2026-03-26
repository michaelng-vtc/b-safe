import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:bsafe_app/features/inspection/providers/inspection_provider.dart';
import 'package:bsafe_app/features/start/view/start_page.dart';
import 'package:bsafe_app/core/theme/app_theme.dart';

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

  runApp(const BSafeApp());
}

class BSafeApp extends StatelessWidget {
  const BSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InspectionProvider()),
      ],
      child: MaterialApp(
        title: 'B-SAFE Building Safety',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const StartScreen(),
      ),
    );
  }
}
