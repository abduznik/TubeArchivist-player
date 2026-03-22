class Channel {
  final String id;
  final String name;
  final String thumbUrl;
  final bool subscribed;

  Channel({
    required this.id,
    required this.name,
    required this.thumbUrl,
    required this.subscribed,
  });

  factory Channel.fromJson(Map<String, dynamic> json, String baseUrl) {
    final cleanBaseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final String channelId = json['channel_id'] ?? '';
    final firstChar = channelId.isNotEmpty ? channelId[0].toLowerCase() : '_';
    final thumbPath = '$cleanBaseUrl/cache/channels/$firstChar/${channelId}_thumb.jpg';

    return Channel(
      id: channelId,
      name: json['channel_name'] ?? 'Unknown Channel',
      thumbUrl: thumbPath,
      subscribed: json['channel_subscribed'] ?? false,
    );
  }
}
