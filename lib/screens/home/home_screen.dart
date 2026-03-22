import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/video.dart';
import '../../models/channel.dart';
import '../../services/preferences_service.dart';
import 'widgets/video_card.dart';
import 'widgets/channel_chip.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<Video> _videos = [];
  final List<Channel> _channels = [];
  
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 0;
  String? _selectedChannelId;
  bool _hasMore = true;
  String _token = ''; // Added token field

  @override
  void initState() {
    super.initState();
    _initApp(); // Call _initApp instead of direct load
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initApp() async {
    final prefs = PreferencesService();
    final token = await prefs.getToken(); // Fetch token
    setState(() {
      _token = token ?? '';
    });
    // Now load channels and videos AFTER token is set
    await _loadChannels();
    await _loadVideos(refresh: true);
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

  Future<void> _loadChannels() async {
    try {
      final channels = await ApiService().getChannels();
      if (mounted) {
        setState(() {
          _channels.clear();
          _channels.addAll(channels);
        });
      }
    } catch (e) {
      // Handle error or just ignore for channel filter
      print('Error loading channels: $e');
    }
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    
    try {
      final newVideos = await ApiService().getVideos(
        page: refresh ? 0 : _currentPage,
        channelId: _selectedChannelId,
      );
      
      newVideos.shuffle(); // shuffle BEFORE adding to list
      
      if (mounted) {
        setState(() {
          if (refresh) {
            _videos.clear();
            _videos.addAll(newVideos);
            _currentPage = 0;
          } else {
            _videos.addAll(newVideos);
          }
          _currentPage++;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar( // show error snackbar
          SnackBar(content: Text('Failed to load videos: $e')),
        );
      }
    }
  }

  void _onChannelSelected(String? channelId) {
    if (_selectedChannelId == channelId) return;
    setState(() {
      _selectedChannelId = channelId;
    });
    _loadVideos(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Channel Filter
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _channels.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return ChannelChip(
                  channel: null,
                  isSelected: _selectedChannelId == null,
                  onTap: () => _onChannelSelected(null),
                );
              }
              final channel = _channels[index - 1];
              return ChannelChip(
                channel: channel,
                isSelected: _selectedChannelId == channel.id,
                onTap: () => _onChannelSelected(channel.id),
              );
            },
          ),
        ),
        
        // Video Grid
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadVideos(refresh: true),
            color: Theme.of(context).primaryColor,
            child: _isLoading && _videos.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 900 
                          ? 4 
                          : constraints.maxWidth > 600 ? 3 : 2;
                      
                      return GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 16 / 14, // Adjust for card content
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: _videos.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _videos.length) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return VideoCard(video: _videos[index], token: _token);
                        },
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
