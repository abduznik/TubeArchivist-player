import 'package:flutter/material.dart';
import '../../../models/download_item.dart';

class QueueItemCard extends StatelessWidget {
  final DownloadItem item;

  const QueueItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.access_time;

    if (item.status.toLowerCase() == 'downloading') {
      statusColor = Colors.blue;
      statusIcon = Icons.downloading;
    } else if (item.status.toLowerCase() == 'failed' || item.message != null) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (item.status.toLowerCase() == 'finished') {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: item.message != null 
            ? Text(item.message!, style: const TextStyle(color: Colors.red))
            : Text('Status: ${item.status}'),
        trailing: item.status.toLowerCase() == 'downloading'
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
    );
  }
}
