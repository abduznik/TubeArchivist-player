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
  int _currentPage = 1;
  String? _selectedChannelId;
  bool _hasMore = true;
  String _token = '';
  String _activeFilter = 'Discover'; // 'Discover' (random) or 'Latest'

  @override
  void initState() {
    super.initState();
    _initApp();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initApp() async {
    final prefs = PreferencesService();
    final token = await prefs.getToken();
    setState(() {
      _token = token ?? '';
    });
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
      print('Error loading channels: $e');
    }
  }

  List<Video> _interleaveByChannel(List<Video> videos) {
    final Map<String, List<Video>> byChannel = {};
    for (final video in videos) {
      byChannel.putIfAbsent(video.channelId, () => []).add(video);
    }
    
    final rand = Random();
    for (final list in byChannel.values) {
      list.shuffle(rand);
    }
    
    final channels = byChannel.keys.toList()..shuffle(rand);
    final result = <Video>[];
    if (byChannel.values.isEmpty) return result;
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

  void _onFilterSelected(String filter) {
    if (_activeFilter == filter) return;
    setState(() {
      _activeFilter = filter;
      _selectedChannelId = null; // Clear channel filter when switching to Latest/Discover
    });
    _loadVideos(refresh: true);
  }

  void _onChannelSelected(String? channelId) {
    if (_selectedChannelId == channelId) return;
    setState(() {
      _selectedChannelId = channelId;
      if (channelId != null) {
        _activeFilter = 'Latest'; // Default to latest when a channel is picked
      }
    });
    _loadVideos(refresh: true);
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if ((_isLoading && refresh) || (_isLoadingMore && !refresh)) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
        _videos.clear();
        _currentPage = 1; 
        _hasMore = true;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      print('HomeScreen: Loading videos, filter: $_activeFilter, page: $_currentPage');
      if (refresh && _activeFilter == 'Discover' && _selectedChannelId == null) {
        // Discover: Interleaved Random Selection
        final firstResult = await ApiService().getVideosWithPagination(
          page: 1, 
          channelId: null,
        );
        final lastPage = firstResult['last_page'] as int;
        final firstVideos = firstResult['videos'] as List<Video>;
        
        print('HomeScreen: Discover - Initial fetch count: ${firstVideos.length}');
        
        final rand = Random();
        final randomPages = <int>{};
        while (randomPages.length < min(4, lastPage - 1)) {
          final pageNum = rand.nextInt(lastPage) + 1;
          if (pageNum != 1) randomPages.add(pageNum);
        }
        
        final futures = randomPages.map((page) =>
          ApiService().getVideos(page: page, channelId: null)
            .catchError((_) => <Video>[])
        ).toList();
        
        final results = await Future.wait(futures);
        final allVideos = [...firstVideos, ...results.expand((e) => e)];
        final seen = <String>{};
        final unique = allVideos.where((v) => seen.add(v.id)).toList();
        
        // Potential performance bottleneck: Interleaving large lists on UI thread
        final interleaved = unique.length > 50 
            ? _interleaveByChannel(unique.take(50).toList()) 
            : _interleaveByChannel(unique);
        
        if (mounted) {
          setState(() {
            _videos.addAll(interleaved);
            _currentPage = 2; 
            _isLoading = false;
            _isLoadingMore = false; 
            _hasMore = interleaved.isNotEmpty; 
          });
        }
      } else {
        // Latest or Channel-specific: Sequential Selection
        List<Video> newVideos;
        if (_activeFilter == 'Latest' && _selectedChannelId == null) {
          newVideos = await ApiService().getRecentVideos(page: _currentPage);
        } else {
          newVideos = await ApiService().getVideos(
            page: _currentPage,
            channelId: _selectedChannelId,
          );
        }

        print('HomeScreen: Loaded ${newVideos.length} sequential videos from page $_currentPage');
        final existingIds = _videos.map((v) => v.id).toSet();
        final uniqueNewVideos = newVideos.where((v) => !existingIds.contains(v.id)).toList();
        
        // Only shuffle if explicitly in Discover mode and loading more
        if (_activeFilter == 'Discover') {
          uniqueNewVideos.shuffle(Random());
        }

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
            print('HomeScreen: Total videos now: ${_videos.length}');
          });
        }
      }
    } catch (e) {
      print('HomeScreen: Error loading videos: $e');
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

  Widget _buildFilterChip(String label, IconData icon) {
    final bool isSelected = _activeFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        selected: isSelected,
        onSelected: (_) => _onFilterSelected(label),
        avatar: Icon(icon, size: 16, color: isSelected ? Colors.black : Colors.white),
        label: Text(label),
        selectedColor: Colors.white,
        backgroundColor: const Color(0xFF272727),
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Filter Bar
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildFilterChip('Discover', Icons.explore_outlined),
              _buildFilterChip('Latest', Icons.new_releases_outlined),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: VerticalDivider(color: Colors.white24, width: 24),
              ),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _channels.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChannelChip(
                          channel: null,
                          isSelected: _selectedChannelId == null && _activeFilter != 'Latest' && _activeFilter != 'Discover',
                          onTap: () => _onChannelSelected(null),
                        ),
                      );
                    }
                    final channel = _channels[index - 1];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChannelChip(
                        channel: channel,
                        isSelected: _selectedChannelId == channel.id,
                        onTap: () => _onChannelSelected(channel.id),
                      ),
                    );
                  },
                ),
              ),
            ],
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
                      final crossAxisCount = constraints.maxWidth > 1200
                          ? 4 
                          : constraints.maxWidth > 800 ? 3 : 2;
                      
                      return GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 16 / 13,
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
