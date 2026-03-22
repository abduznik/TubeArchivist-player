class Video {
  final String id;
  final String title;
  final String channelId;
  final String channelName;
  final String thumbUrl; // Constructed using baseUrl
  final String mediaUrl; // Constructed using baseUrl
  final int duration;
  final bool watched;
  final DateTime published;

  Video({
    required this.id,
    required this.title,
    required this.channelId,
    required this.channelName,
    required this.thumbUrl,
    required this.mediaUrl,
    required this.duration,
    required this.watched,
    required this.published,
  });

  factory Video.fromJson(Map<String, dynamic> json, String baseUrl) {
    // Helper to ensure baseUrl doesn't end with slash if path starts with it, or vice versa
    String buildUrl(String path) {
      if (path.startsWith('http')) return path; // Already full URL
      
      final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
      final cleanPath = path.startsWith('/') ? path : '/$path';
      return '$cleanBase$cleanPath';
    }

    final String videoId = json['youtube_id'] ?? '';
    final channelData = json['channel'] ?? {};
    final playerData = json['player'] ?? {};

    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final firstChar = videoId.isNotEmpty ? videoId[0].toLowerCase() : '_';
    
    // Construct thumbnail URL with correct path
    final thumbPath = '$cleanBaseUrl/cache/videos/$firstChar/$videoId.jpg';
    
    // Construct media URL - API response usually contains a relative path
    // If not present, we might need a fallback, but assuming it is present as 'url' or similar in a real response
    // Based on spec: "media_url field from response"
    // Adjusting based on standard TA API structure if known, or generic field
    // Assuming 'media_url' is at root or inside player.
    // Let's look for 'media_url' at root based on prompt spec
    final rawMediaUrl = json['media_url'] ?? ''; 

    return Video(
      id: videoId,
      title: json['title'] ?? 'Unknown Title',
      channelId: channelData['channel_id'] ?? '',
      channelName: channelData['channel_name'] ?? 'Unknown Channel',
      thumbUrl: buildUrl(thumbPath),
      mediaUrl: buildUrl(rawMediaUrl),
      duration: playerData['duration'] ?? 0,
      watched: playerData['watched'] ?? false,
      published: DateTime.tryParse(json['published'] ?? '') ?? DateTime.now(),
    );
  }
}
