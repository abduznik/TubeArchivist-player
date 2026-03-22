import 'package:flutter/material.dart';
import 'services/preferences_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize preferences
  final prefs = PreferencesService();
  await prefs.init();
  
  final isLoggedIn = prefs.hasCredentials();

  runApp(TubeArchivistApp(isLoggedIn: isLoggedIn));
}
