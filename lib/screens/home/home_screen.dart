import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/video.dart';
import '../../models/channel.dart';
import '../../services/preferences_service.dart';
import 'widgets/video_card.dart';
import 'widgets/channel_chip.dart';
import 'dart:math' show Random, max, min; // Modified import for Random, max, and min

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

  List<Video> _interleaveByChannel(List<Video> videos) {
    // Group videos by channel
    final Map<String, List<Video>> byChannel = {};
    for (final video in videos) {
      byChannel.putIfAbsent(video.channelId, () => []).add(video);
    }
    
    // Shuffle within each channel's list
    final rand = Random();
    for (final list in byChannel.values) {
      list.shuffle(rand);
    }
    
    // Get channel keys and shuffle their order too
    final channels = byChannel.keys.toList()..shuffle(rand);
    
    // Round-robin interleave: take one video from each channel in turn
    final result = <Video>[];
    if (byChannel.values.isEmpty) return result; // Handle empty case
    int maxLen = byChannel.values.map((l) => l.length).reduce(max);
    for (int i = 0; i < maxLen; i++) {
      for (final channel in channels) {
        final list = byChannel[channel]!;
        if (i < list.length) {
          result.add(list[i]);
        }
      }
    }
    return result;
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if ((_isLoading && refresh) || (_isLoadingMore && !refresh)) return;

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
      if (refresh) {
        // First call to get total pages
        final firstResult = await ApiService().getVideosWithPagination(
          page: 0, 
          channelId: _selectedChannelId,
        );
        final lastPage = firstResult['last_page'] as int;
        final firstVideos = firstResult['videos'] as List<Video>;

        // Pick 4 additional random pages spread across the library
        final rand = Random();
        final randomPages = <int>{};
        while (randomPages.length < min(4, lastPage)) { // min(4, lastPage) ensures we don't try to fetch more pages than exist
          final pageNum = rand.nextInt(lastPage + 1);
          if (pageNum != 0) { // Exclude page 0 as it's already fetched
            randomPages.add(pageNum);
          }
        }
        
        // Fetch random pages in parallel
        final futures = randomPages.map((page) =>
          ApiService().getVideos(page: page, channelId: _selectedChannelId)
            .catchError((_) => <Video>[])
        ).toList(); // Convert to List<Future<List<Video>>>
        
        final results = await Future.wait(futures);
        
        // Combine all videos
        final allVideos = [...firstVideos, ...results.expand((e) => e)];
        
        // Deduplicate
        final seen = <String>{};
        final unique = allVideos.where((v) => seen.add(v.id)).toList();
        
        // Interleave by channel
        final interleaved = _interleaveByChannel(unique);
        
        if (mounted) {
          setState(() {
            _videos.clear(); 
            _videos.addAll(interleaved);
            _currentPage = lastPage + 1; // Signal no more pages to load sequentially
            _isLoading = false;
            _isLoadingMore = false; 
            _hasMore = interleaved.isNotEmpty; 
          });
        }
      } else { // Load more on scroll
        List<Video> newVideos = await ApiService().getVideos(
          page: _currentPage,
          channelId: _selectedChannelId,
        );

        // Deduplicate against existing videos
        final existingIds = _videos.map((v) => v.id).toSet();
        final uniqueNewVideos = newVideos.where((v) => !existingIds.contains(v.id)).toList();
        
        // No interleaving needed for paginated additions, but still shuffle
        uniqueNewVideos.shuffle(Random()); 

        if (mounted) {
          setState(() {
            if (uniqueNewVideos.isEmpty && newVideos.isEmpty) {
              _hasMore = false;
            } else {
              _videos.addAll(uniqueNewVideos);
              _currentPage++;
            }
            _isLoading = false; 
            _isLoadingMore = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar( 
          SnackBar(content: Text('Failed to load videos: $e')),
        );
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
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
