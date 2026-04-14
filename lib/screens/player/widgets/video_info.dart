import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../models/video.dart';

class VideoInfo extends StatelessWidget {
  final Video video;
  final VoidCallback onDownload;
  final bool isDownloading;
  final double downloadProgress;

  const VideoInfo({
    super.key,
    required this.video,
    required this.onDownload,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${video.channelName} • ${timeago.format(video.published)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isDownloading)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    value: downloadProgress, 
                    strokeWidth: 2,
                  ),
                )
              else
                IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: onDownload,
                  tooltip: 'Download for offline',
                ),
            ],
          ),
          if (isDownloading)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: LinearProgressIndicator(value: downloadProgress),
            ),
          const SizedBox(height: 16),
          // Description could go here if available in Video model
          // Since Video model is limited, we just show what we have.
        ],
      ),
    );
  }
}
