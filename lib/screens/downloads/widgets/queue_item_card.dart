import 'package:flutter/material.dart';
import '../../../models/download_item.dart';
import '../../../services/api_service.dart';

class QueueItemCard extends StatelessWidget {
  final DownloadItem item;

  const QueueItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    bool isFailed = item.status.toLowerCase() == 'failed' || item.message != null;
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.access_time;

    if (item.status.toLowerCase() == 'downloading') {
      statusColor = Colors.blue;
      statusIcon = Icons.downloading;
    } else if (isFailed) {
      statusColor = Colors.red;
      statusIcon = Icons.error_outline;
    } else if (item.status.toLowerCase() == 'finished') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: item.message != null 
            ? Text(item.message!, style: const TextStyle(color: Colors.red, fontSize: 11))
            : Text('Status: ${item.status}'),
        trailing: item.status.toLowerCase() == 'downloading'
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : isFailed
                ? IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.blue),
                    onPressed: () => ApiService().retryDownload(item.id),
                    tooltip: 'Retry Download',
                  )
                : null,
      ),
    );
  }
}
