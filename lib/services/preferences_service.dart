import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveCredentials(String url, String token) async {
    // Remove trailing slash from URL if present for consistency
    final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    await _prefs.setString(AppConstants.keyServerUrl, cleanUrl);
    await _prefs.setString(AppConstants.keyApiToken, token);
  }

  String? getServerUrl() {
    return _prefs.getString(AppConstants.keyServerUrl);
  }

  String? getApiToken() {
    return _prefs.getString(AppConstants.keyApiToken);
  }

  Future<String?> getToken() async {
    return _prefs.getString(AppConstants.keyApiToken);
  }

  bool hasCredentials() {
    return _prefs.containsKey(AppConstants.keyServerUrl) && 
           _prefs.containsKey(AppConstants.keyApiToken);
  }
}
