import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/download_service.dart';
import '../../models/download_item.dart';
import '../../models/video.dart';
import 'widgets/queue_item_card.dart';
import 'widgets/offline_video_card.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final TextEditingController _urlController = TextEditingController();
  
  List<DownloadItem> _queue = [];
  List<Video> _offlineVideos = [];
  Timer? _refreshTimer;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this); // Register observer
    _loadQueue();
    _loadOfflineVideos();
    _startTimer();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    _urlController.dispose();
    WidgetsBinding.instance.removeObserver(this); // Unregister observer
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer(); // Start timer when app resumes
      _loadQueue(); // Also refresh immediately
      _loadOfflineVideos();
    } else if (state == AppLifecycleState.paused) {
      _refreshTimer?.cancel(); // Cancel timer when app pauses
    }
  }

  void _startTimer() {
    _refreshTimer?.cancel(); // Cancel any existing timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) { // Increased interval to 10 seconds
      if (mounted && _tabController.index == 0) { // Only refresh if on Queue tab
        _loadQueue();
      }
    });
  }

  Future<void> _loadQueue() async {
    try {
      final queue = await ApiService().getDownloadQueue();
      if (mounted) {
        setState(() => _queue = queue);
      }
    } catch (e) {
      debugPrint('Error loading queue: $e');
    }
  }

  Future<void> _loadOfflineVideos() async {
    try {
      final videos = await DownloadService().getDownloadedVideos();
      if (mounted) {
        setState(() => _offlineVideos = videos);
      }
    } catch (e) {
      debugPrint('Error loading offline videos: $e');
    }
  }

  Future<void> _addToQueue() async {
    if (_urlController.text.isEmpty) return;
    
    setState(() => _isAdding = true);
    try {
      await ApiService().addToQueue(_urlController.text.trim());
      _urlController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to queue')),
        );
        _loadQueue(); // Immediate refresh
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteOfflineVideo(String videoId) async {
    try {
      await DownloadService().deleteVideo(videoId);
      _loadOfflineVideos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Queue'),
            Tab(text: 'Offline'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Queue Tab
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlController,
                            decoration: const InputDecoration(
                              hintText: 'Paste YouTube URL',
                              prefixIcon: Icon(Icons.link),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isAdding ? null : () => _addToQueue(), // Wrapped in anonymous function
                          icon: _isAdding 
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.add),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _queue.isEmpty
                        ? const Center(child: Text('Queue is empty'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _queue.length,
                            itemBuilder: (context, index) {
                              return QueueItemCard(item: _queue[index]);
                            },
                          ),
                  ),
                ],
              ),
              
              // Offline Tab
              _offlineVideos.isEmpty
                  ? const Center(child: Text('No offline videos'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _offlineVideos.length,
                      itemBuilder: (context, index) {
                        final video = _offlineVideos[index];
                        return OfflineVideoCard(
                          video: video,
                          onDelete: () => _deleteOfflineVideo(video.id),
                        );
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }
}
