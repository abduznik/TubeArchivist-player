import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/video.dart';
import '../../services/api_service.dart';
import '../../services/preferences_service.dart';
import '../../services/download_service.dart';
import 'widgets/video_info.dart';

class PlayerScreen extends StatefulWidget {
  final Video video;

  const PlayerScreen({super.key, required this.video});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  Timer? _progressTimer;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    if (defaultTargetPlatform != TargetPlatform.windows) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    final appDir = await getApplicationDocumentsDirectory();
    final localPath = '${appDir.path}/downloads/${widget.video.id}.mp4';
    final localFile = File(localPath);
    
    if (await localFile.exists()) {
      // MUST use file controller - no network involved at all
      _videoPlayerController = VideoPlayerController.file(localFile);
      if (mounted) { // Ensure mounted before setState
        setState(() => _isOffline = true);
      }
    } else {
      // Only use network if local file does NOT exist
      final prefs = PreferencesService();
      final token = await prefs.getToken() ?? '';
      final serverUrl = await prefs.getServerUrl() ?? '';
      final fullUrl = widget.video.mediaUrl.startsWith('http')
          ? widget.video.mediaUrl
          : '$serverUrl${widget.video.mediaUrl}';
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(fullUrl),
        httpHeaders: {'Authorization': 'Token $token'},
      );
      if (mounted) { // Ensure mounted before setState
        setState(() => _isOffline = false);
      }
    }
    
    // Debug print
    print('Playing offline: $_isOffline, path: $localPath');

    try {
      await _videoPlayerController!.initialize();
      
      // Load saved progress if any
      try {
        final progress = await ApiService()
            .getProgress(widget.video.id)
            .timeout(const Duration(seconds: 3));
        if (progress != null && progress.positionSeconds > 0) {
          await _videoPlayerController!.seekTo(Duration(seconds: progress.positionSeconds));
        }
      } catch (_) {
        // No network or timeout — skip progress restore, play from beginning
      }

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (mounted) setState(() {});

      // Start progress saving timer
      _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (_videoPlayerController!.value.isPlaying) {
          ApiService().saveProgress(
            widget.video.id, 
            _videoPlayerController!.value.position.inSeconds,
          );
        }
      });

    } catch (e) {
      print('Error initializing player: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing video: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _downloadVideo() async {
    if (_isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      await DownloadService().downloadVideo(widget.video, (progress) {
        if (mounted) {
          setState(() => _downloadProgress = progress);
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Download complete!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
          _initializePlayer(); // Re-initialize player to detect offline status
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.windows) {
      // Windows fallback — show video info only, no player
      return Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F0F0F),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.desktop_windows, color: Color(0xFF717171), size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Video playback is not supported on Windows desktop.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use the Android app to watch videos.',
                  style: TextStyle(color: Color(0xFF717171), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Still show video info below
                VideoInfo(
                  video: widget.video,
                  onDownload: _downloadVideo,
                  isDownloading: _isDownloading,
                  downloadProgress: _downloadProgress,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.title),
      ),
      body: Column(
        children: [
          // Player Area
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _chewieController != null &&
                    _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const Center(child: CircularProgressIndicator()),
          ),
          
          if (_isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: const [
                  Icon(Icons.offline_pin, color: Color(0xFF00C853), size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Playing offline',
                    style: TextStyle(color: Color(0xFF00C853), fontSize: 12),
                  ),
                ],
              ),
            ),
          
          // Info Area
          Expanded(
            child: SingleChildScrollView(
              child: VideoInfo(
                video: widget.video,
                onDownload: _downloadVideo,
                isDownloading: _isDownloading,
                downloadProgress: _downloadProgress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
