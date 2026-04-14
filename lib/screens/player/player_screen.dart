import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mk;
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
  // MediaKit controllers
  late final Player _player = Player(
    configuration: PlayerConfiguration(
      title: 'TubeArchivist Player',
      // Increase buffer size to 64MB for smoother initial buffering
      bufferSize: 64 * 1024 * 1024,
      ready: () {
        debugPrint('Player ready');
        if (_player.platform is NativePlayer) {
          final native = _player.platform as NativePlayer;
          // Set essential MPV properties for high-res streaming
          native.setProperty('vo', 'gpu');
          native.setProperty('hwdec', 'auto-safe');
          native.setProperty('fast-seek', 'yes');
          native.setProperty('demuxer-seekable-cache', 'yes');
          // Buffering tweaks for snappy streaming
          native.setProperty('demuxer-readahead-secs', '60'); 
          native.setProperty('demuxer-max-bytes', '157286400'); // 150MB forward readahead
          native.setProperty('demuxer-max-back-bytes', '52428800'); // 50MB backward cache
          // Performance and network
          native.setProperty('cache-pause', 'no');
          native.setProperty('network-timeout', '30');
        }
      },
    ),
  );
  late final mk.VideoController _videoController = mk.VideoController(
    _player,
    configuration: const mk.VideoControllerConfiguration(
      enableHardwareAcceleration: true,
    ),
  );

  
  Timer? _progressTimer;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _isOffline = false;
  bool _isInitialized = false;
  List<Video> _relatedVideos = [];
  List<dynamic> _comments = [];
  bool _isLoadingExtras = false;
  String? _token;

  StreamSubscription? _errorSubscription;

  @override
  void initState() {
    super.initState();
    _errorSubscription = _player.stream.error.listen((error) {
      debugPrint('MediaKit Error: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Playback error: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
    _initializePlayer();
    _loadExtras();
  }

  Future<void> _loadExtras() async {
    setState(() => _isLoadingExtras = true);
    try {
      final prefs = PreferencesService();
      final token = await prefs.getToken();
      final related = await ApiService().getRelatedVideos(widget.video.id);
      final comments = await ApiService().getComments(widget.video.id);
      if (mounted) {
        setState(() {
          _token = token;
          _relatedVideos = related;
          _comments = comments;
          _isLoadingExtras = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingExtras = false);
    }
  }

  Future<void> _initializePlayer() async {
    final appDir = await getApplicationDocumentsDirectory();
    if (!mounted) return;
    final localPath = '${appDir.path}/downloads/${widget.video.id}.mp4';
    final localFile = File(localPath);
    
    final prefs = PreferencesService();
    final token = await prefs.getToken() ?? '';
    final serverUrl = await prefs.getServerUrl() ?? '';
    if (!mounted) return;
    
    try {
      if (await localFile.exists()) {
        _isOffline = true;
        await _player.open(Media(localFile.path));
      } else {
        _isOffline = false;
        // Video model already builds the full URL in Video.fromJson
        final fullUrl = widget.video.mediaUrl;
        
        await _player.open(
          Media(
            fullUrl,
            httpHeaders: {
              'Authorization': 'Token $token',
              'User-Agent': 'TubeArchivistCompanion/1.1.0 (Flutter; macOS/Windows/Android)',
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('MediaKit Open Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    if (!mounted) return;

    try {
      final progress = await ApiService()
          .getProgress(widget.video.id)
          .timeout(const Duration(seconds: 3));
      
      if (!mounted) return;
      
      if (progress != null && progress.positionSeconds > 0) {
        await _player.seek(Duration(seconds: progress.positionSeconds));
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }

    _progressTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_player.state.playing) {
        ApiService().saveProgress(
          widget.video.id, 
          _player.state.position.inSeconds,
        );
      }
    });
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _player.dispose();
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
        });
      }
    }
  }

  Widget _buildPlayer() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: _isInitialized
            ? mk.Video(
                controller: _videoController,
                fit: BoxFit.contain,
                controls: mk.AdaptiveVideoControls,
              )
            : const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VideoInfo(
            video: widget.video,
            onDownload: _downloadVideo,
            isDownloading: _isDownloading,
            downloadProgress: _downloadProgress,
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
          const Divider(),
          
          if (_comments.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  const Icon(Icons.comment, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Comments (${_comments.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length > 3 ? 3 : _comments.length,
              itemBuilder: (context, index) {
                final comment = _comments[index];
                return ListTile(
                  dense: true,
                  leading: const CircleAvatar(radius: 14, child: Icon(Icons.person, size: 16)),
                  title: Text(comment['author'] ?? 'Anonymous', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  subtitle: Text(comment['text'] ?? '', style: const TextStyle(fontSize: 12)),
                );
              },
            ),
            const Divider(),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: const [
                Icon(Icons.video_library, size: 20),
                SizedBox(width: 8),
                Text(
                  'Related Videos',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          if (_isLoadingExtras)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ))
          else if (_relatedVideos.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No related videos found'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _relatedVideos.length,
              itemBuilder: (context, index) {
                final v = _relatedVideos[index];
                return ListTile(
                  leading: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      v.thumbUrl,
                      fit: BoxFit.cover,
                      headers: _token != null ? {'Authorization': 'Token $_token'} : null,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey),
                    ),
                  ),
                  title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(v.channelName, style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    _player.stop();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => PlayerScreen(video: v)),
                    );
                  },
                );
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            // Desktop Layout: Side-by-side
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Container(
                          color: Colors.black,
                          alignment: Alignment.center,
                          child: _buildPlayer(),
                        ),
                        // You could add more content here that stays under the video on desktop
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _buildInfoSection(),
                ),
              ],
            );
          } else {
            // Mobile Layout: Vertical
            return Column(
              children: [
                _buildPlayer(),
                Expanded(
                  child: _buildInfoSection(),
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
