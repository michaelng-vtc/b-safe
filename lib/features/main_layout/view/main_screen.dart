import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bsafe_app/features/main_layout/controller/main_layout_controller.dart';
import 'package:bsafe_app/features/home/view/home_page.dart';
import 'package:bsafe_app/features/monitor/view/monitor_page.dart';
import 'package:bsafe_app/features/settings/view/settings_page.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MainLayoutController(),
      child: Consumer<MainLayoutController>(
        builder: (context, controller, _) {
          final pages = <Widget>[
            const HomeScreen(),
            const LocationScreen(),
            const SettingsPage(),
          ];

          return Scaffold(
            body: pages[controller.currentIndex],
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: controller.currentIndex,
              onTap: controller.setIndex,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.monitor_heart_outlined),
                  activeIcon: Icon(Icons.monitor_heart),
                  label: 'Monitor',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
