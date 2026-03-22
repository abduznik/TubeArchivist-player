import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'core/constants.dart';
import 'widgets/app_shell.dart';
import 'screens/settings/settings_screen.dart';

class TubeArchivistApp extends StatelessWidget {
  final bool isLoggedIn;

  const TubeArchivistApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: isLoggedIn ? const AppShell() : const SettingsScreen(isFirstLaunch: true),
    );
  }
}
