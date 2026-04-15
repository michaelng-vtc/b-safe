import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smartsurvey/features/inspection/presentation/providers/inspection_provider.dart';
import 'package:smartsurvey/features/start/presentation/views/start_page.dart';
import 'package:smartsurvey/core/theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => InspectionProvider()),
      ],
      child: MaterialApp(
        title: 'SmartSurvey Building Safety',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const StartScreen(),
      ),
    );
  }
}
