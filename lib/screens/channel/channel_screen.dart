import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/video.dart';
import '../../models/channel.dart';
import '../../services/preferences_service.dart';
import '../home/widgets/video_card.dart';

class ChannelScreen extends StatefulWidget {
  final String channelId;
  final String channelName;

  const ChannelScreen({
    super.key, 
    required this.channelId, 
    required this.channelName,
  });

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Video> _videos = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  bool _hasMore = true;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadInitialData() async {
    final prefs = PreferencesService();
    final token = await prefs.getToken() ?? '';
    if (mounted) {
      setState(() => _token = token);
    }
    _loadVideos(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore && _hasMore) {
      _loadVideos();
    }
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if ((_isLoading && !refresh) || _isLoadingMore) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
        _videos.clear();
        _currentPage = 0;
        _hasMore = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final videos = await ApiService().getVideos(
        page: _currentPage,
        channelId: widget.channelId,
      );

      if (mounted) {
        setState(() {
          _videos.addAll(videos);
          _currentPage++;
          _hasMore = videos.isNotEmpty;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load channel videos: $e')),
        );
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channelName),
      ),
      body: _isLoading && _videos.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadVideos(refresh: true),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            child: Text(
                              widget.channelName[0].toUpperCase(),
                              style: const TextStyle(fontSize: 32),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.channelName,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_videos.length}+ videos',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16.0),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 16 / 14,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == _videos.length) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return VideoCard(video: _videos[index], token: _token);
                        },
                        childCount: _videos.length + (_isLoadingMore ? 1 : 0),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
