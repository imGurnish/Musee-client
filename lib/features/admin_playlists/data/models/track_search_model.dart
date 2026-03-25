class TrackSearchModel {
  final String trackId;
  final String title;
  final int duration;
  final List<String> artistNames;
  final String? albumId;
  final bool isPublished;

  TrackSearchModel({
    required this.trackId,
    required this.title,
    required this.duration,
    required this.artistNames,
    this.albumId,
    required this.isPublished,
  });

  factory TrackSearchModel.fromJson(Map<String, dynamic> json) {
    final artists = (json['artists'] as List? ?? [])
        .map((a) => (a is Map ? a['name'] as String? : null) ?? '')
        .whereType<String>()
        .toList();

    return TrackSearchModel(
      trackId: json['track_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      artistNames: artists,
      albumId: json['album_id'] as String?,
      isPublished: json['is_published'] as bool? ?? false,
    );
  }
}
