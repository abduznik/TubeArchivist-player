class DownloadItem {
  final String id;
  final String title;
  final String status;
  final String? message;
  final String? thumbUrl;

  DownloadItem({
    required this.id,
    required this.title,
    required this.status,
    this.message,
    this.thumbUrl,
  });

  factory DownloadItem.fromJson(Map<String, dynamic> json) {
    return DownloadItem(
      id: json['youtube_id'] ?? '',
      title: json['title'] ?? 'Unknown',
      status: json['status'] ?? 'pending',
      message: json['message'],
      thumbUrl: json['thumb_url'], // Assuming API might provide this, or we construct it if needed
    );
  }
}
