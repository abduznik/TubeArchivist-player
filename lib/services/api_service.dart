import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/video.dart';
import '../models/channel.dart';
import '../models/download_item.dart';
import '../models/watch_progress.dart';
import 'preferences_service.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final PreferencesService _prefs = PreferencesService();

  Map<String, String> get _headers {
    final token = _prefs.getApiToken();
    return {
      'Authorization': 'Token $token',
      'Content-Type': 'application/json',
    };
  }

  String get _baseUrl {
    final url = _prefs.getServerUrl();
    if (url == null || url.isEmpty) throw Exception('Server URL not configured');
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Future<Map<String, dynamic>> getVideosWithPagination({
    int page = 0,
    String? channelId,
  }) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointVideo}')
        .replace(queryParameters: {
          'page': page.toString(),
          'page_size': '50', 
          'ordering': '?', 
          if (channelId != null) 'channel': channelId,
        });

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<Video> videos = (data['data'] as List)
          .map((v) => Video.fromJson(v, _baseUrl))
          .toList();
      final int lastPage = data['paginate']['last_page'] as int;
      return {
        'videos': videos,
        'last_page': lastPage,
      };
    } else {
      throw Exception('Failed to load videos with pagination: ${response.statusCode}');
    }
  }

  Future<List<Video>> getVideos({int page = 0, String? channelId}) async {
    final queryParams = {
      'page': page.toString(),
      if (channelId != null) 'channel': channelId,
    };
    
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointVideo}')
        .replace(queryParameters: {
          'page': page.toString(),
          'page_size': '50', // Add page_size parameter for more videos per page
          'ordering': '?', 
          if (channelId != null) 'channel': channelId,
        });

    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // Handle both direct list or {"data": []} format
      final List<dynamic> data = json is List ? json : (json['data'] ?? []);
      return data.map((e) => Video.fromJson(e, _baseUrl)).toList();
    } else {
      throw Exception('Failed to load videos: ${response.statusCode}');
    }
  }

  Future<Video> getVideo(String videoId) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointVideo}$videoId/');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // TA API usually returns the object directly for ID lookup
      // But sometimes wrapped in data.
      final data = json.containsKey('data') ? json['data'] : json;
      return Video.fromJson(data, _baseUrl);
    } else {
      throw Exception('Failed to load video: ${response.statusCode}');
    }
  }

  Future<List<Video>> searchVideos(String query) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointVideo}')
        .replace(queryParameters: {'search': query});
    
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> data = json is List ? json : (json['data'] ?? []);
      return data.map((e) => Video.fromJson(e, _baseUrl)).toList();
    } else {
      throw Exception('Failed to search videos: ${response.statusCode}');
    }
  }

  Future<List<Channel>> getChannels() async {
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointChannel}');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> data = json is List ? json : (json['data'] ?? []);
      return data.map((e) => Channel.fromJson(e, _baseUrl)).toList();
    } else {
      throw Exception('Failed to load channels: ${response.statusCode}');
    }
  }

  Future<WatchProgress?> getProgress(String videoId) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointVideo}$videoId/progress');
    // Note: This endpoint might not exist in all TA versions or might be different. 
    // Implementing strictly as requested.
    try {
      final response = await http.get(uri, headers: _headers);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return WatchProgress.fromJson(json);
      }
    } catch (e) {
      // Ignore errors for progress fetch, treat as no progress
    }
    return null;
  }

  Future<void> saveProgress(String videoId, int positionSeconds) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointVideo}$videoId/progress');
    final body = jsonEncode({'position': positionSeconds});
    
    // Fire and forget - or we can await it.
    await http.post(uri, headers: _headers, body: body);
  }

  Future<List<DownloadItem>> getDownloadQueue() async {
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointDownload}');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final List<dynamic> data = json is List ? json : (json['data'] ?? []);
      return data.map((e) => DownloadItem.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load download queue: ${response.statusCode}');
    }
  }

  Future<void> addToQueue(String youtubeUrl) async {
    final uri = Uri.parse('$_baseUrl${AppConstants.endpointDownload}');
    
    // If user provided a full URL, try to extract ID, otherwise send as is.
    // Simple regex for ID extraction (optional but good for UX)
    String id = youtubeUrl;
    final regExp = RegExp(r'(?<=v=)[a-zA-Z0-9_-]{11}|(?<=be\/)[a-zA-Z0-9_-]{11}');
    final match = regExp.firstMatch(youtubeUrl);
    if (match != null) {
      id = match.group(0)!;
    }

    final body = jsonEncode({
      "data": [
        {"youtube_id": id, "status": "pending"}
      ]
    });

    final response = await http.post(uri, headers: _headers, body: body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      throw Exception('Failed to add to queue: ${response.body}');
    }
  }

  Future<bool> testConnection() async {
    try {
      final uri = Uri.parse('$_baseUrl${AppConstants.endpointPing}');
      final response = await http.get(uri, headers: _headers);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
