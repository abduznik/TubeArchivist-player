import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video.dart';
import 'preferences_service.dart';
import 'package:dio/io.dart'; // Import for IOHttpClientAdapter

class DownloadService {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal() {
    // Issue 1: HTTP cleartext blocked for downloads
    (_dio.httpClientAdapter as IOHttpClientAdapter).createHttpClient = () {
      final client = HttpClient();
      client.badCertificateCallback = (cert, host, port) => true;
      return client;
    };
  }

  final Dio _dio = Dio();

  Future<String> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    return downloadDir.path;
  }

  Future<List<Video>> getDownloadedVideos() async {
    final dirPath = await _getDownloadDirectory();
    final dir = Directory(dirPath);
    final List<Video> videos = [];

    if (await dir.exists()) {
      final List<FileSystemEntity> entities = dir.listSync();
      for (var entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final jsonString = await entity.readAsString();
            final jsonMap = jsonDecode(jsonString);
            
            final baseUrl = PreferencesService().getServerUrl() ?? '';
            final video = Video.fromJson(jsonMap, baseUrl);
            
            // Check if the actual video file exists
            final videoFilePath = entity.path.replaceAll('.json', '.mp4');
            if (await File(videoFilePath).exists()) {
               videos.add(Video(
                 id: video.id,
                 title: video.title,
                 channelId: video.channelId,
                 channelName: video.channelName,
                 thumbUrl: video.thumbUrl,
                 mediaUrl: videoFilePath, // LOCAL PATH
                 duration: video.duration,
                 watched: video.watched,
                 published: video.published,
               ));
            }
          } catch (e) {
            print('Error parsing local video metadata: $e');
          }
        }
      }
    }
    return videos;
  }

  Future<void> downloadVideo(Video video, Function(double progress) onProgress) async {
    final dirPath = await _getDownloadDirectory();
    final savePath = '$dirPath/${video.id}.mp4';
    final metadataPath = '$dirPath/${video.id}.json';

    // 1. Download Video
    try {
      final token = PreferencesService().getApiToken();
      
      await _dio.download(
        video.mediaUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total); // Issue 3: Show download progress
          }
        },
        options: Options(
          headers: {
            'Authorization': 'Token $token',
          }
        ),
      );

      // 2. Save Metadata
      final metaMap = {
        'youtube_id': video.id,
        'title': video.title,
        'channel': {
          'channel_id': video.channelId,
          'channel_name': video.channelName,
        },
        'player': {
          'duration': video.duration,
          'watched': video.watched,
        },
        'published': video.published.toIso8601String(),
      };

      await File(metadataPath).writeAsString(jsonEncode(metaMap));
      
    } catch (e) {
      // Cleanup if failed
      if (await File(savePath).exists()) await File(savePath).delete();
      if (await File(metadataPath).exists()) await File(metadataPath).delete();
      rethrow;
    }
  }

  Future<void> deleteVideo(String videoId) async {
    final dirPath = await _getDownloadDirectory();
    final videoPath = '$dirPath/$videoId.mp4';
    final metaPath = '$dirPath/$videoId.json';

    final vFile = File(videoPath);
    final mFile = File(metaPath);

    if (await vFile.exists()) await vFile.delete();
    if (await mFile.exists()) await mFile.delete();
  }
}
