import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/video.dart';
import '../../services/preferences_service.dart';
import '../home/widgets/video_card.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<Video> _watchedVideos = [];
  List<Video> _continueWatching = [];
  bool _isLoading = true;
  String _token = '';

  @override
  void initState() {
    super.initState();
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    setState(() => _isLoading = true);
    try {
      final prefs = PreferencesService();
      final token = await prefs.getToken() ?? '';
      
      // Parallel fetch
      final results = await Future.wait([
        ApiService().getLibrary(),
        ApiService().getContinueWatching(),
      ]);

      if (mounted) {
        setState(() {
          _token = token;
          _watchedVideos = results[0];
          _continueWatching = results[1];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLibrary,
              child: CustomScrollView(
                slivers: [
                  // Continue Watching Section
                  if (_continueWatching.isNotEmpty) ...[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Continue Watching',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 180,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _continueWatching.length,
                          itemBuilder: (context, index) {
                            return SizedBox(
                              width: 200,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: VideoCard(video: _continueWatching[index], token: _token),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // History Section
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'History',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (_watchedVideos.isEmpty && _continueWatching.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('No library content found')),
                    )
                  else if (_watchedVideos.isEmpty)
                    const SliverToBoxAdapter(
                      child: Center(child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Text('No watch history found'),
                      )),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                          childAspectRatio: 16 / 13,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return VideoCard(video: _watchedVideos[index], token: _token);
                          },
                          childCount: _watchedVideos.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
    );
  }
}
