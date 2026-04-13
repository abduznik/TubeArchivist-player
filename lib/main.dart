import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'services/preferences_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize MediaKit for cross-platform video playback
  MediaKit.ensureInitialized();
  
  // Initialize preferences
  final prefs = PreferencesService();
  await prefs.init();
  
  final isLoggedIn = prefs.hasCredentials();

  runApp(TubeArchivistApp(isLoggedIn: isLoggedIn));
}
