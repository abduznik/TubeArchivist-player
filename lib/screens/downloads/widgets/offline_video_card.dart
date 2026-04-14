import 'package:flutter/material.dart';
import '../../../models/video.dart';
import '../../player/player_screen.dart';

class OfflineVideoCard extends StatelessWidget {
  final Video video;
  final VoidCallback onDelete;

  const OfflineVideoCard({
    super.key, 
    required this.video,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Colors.red,
          child: Icon(Icons.play_arrow, color: Colors.white),
        ),
        title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(video.channelName),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.grey),
          onPressed: onDelete,
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlayerScreen(video: video),
            ),
          );
        },
      ),
    );
  }
}
