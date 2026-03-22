class WatchProgress {
  final String videoId;
  final int positionSeconds;

  WatchProgress({
    required this.videoId,
    required this.positionSeconds,
  });

  factory WatchProgress.fromJson(Map<String, dynamic> json) {
    return WatchProgress(
      videoId: json['video_id'] ?? '',
      positionSeconds: json['position'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'position': positionSeconds,
    };
  }
}
