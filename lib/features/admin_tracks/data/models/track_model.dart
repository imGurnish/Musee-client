import '../../domain/entities/track.dart';

class TrackModel extends Track {
  TrackModel({
    required super.trackId,
    super.extTrackId,
    required super.title,
    super.albumId,
    super.language,
    super.releaseDate,
    super.lyricsUrl,
    required super.duration,
    required super.playCount,
    required super.isExplicit,
    required super.likesCount,
    required super.popularityScore,
    required super.createdAt,
    required super.updatedAt,
    super.videoUrl,
    required super.isPublished,
    required super.artists,
    required super.audios,
  });

  factory TrackModel.fromJson(Map<String, dynamic> json) {
    final artistsList = (json['artists'] as List? ?? []).map((e) {
      final m = Map<String, dynamic>.from(e);
      return TrackArtist(
        artistId: m['artist_id']?.toString() ?? '',
        role: m['role']?.toString(),
        name: m['name']?.toString() ?? '',
        avatarUrl: m['avatar_url'] as String?,
      );
    }).toList();

    final audiosList = (json['audios'] as List? ?? []).map((e) {
      final m = Map<String, dynamic>.from(e);
      return TrackAudio(
        id: m['id']?.toString() ?? '',
        ext: m['ext']?.toString() ?? '',
        bitrate: (m['bitrate'] as num?)?.toInt() ?? 0,
        path: m['path']?.toString() ?? '',
        createdAt: m['created_at'] != null
            ? DateTime.parse(m['created_at'].toString())
            : null,
      );
    }).toList();

    return TrackModel(
      trackId: json['track_id']?.toString() ?? json['id']?.toString() ?? '',
      extTrackId: json['ext_track_id']?.toString(),
      title: json['title']?.toString() ?? '',
      albumId: json['album_id']?.toString(),
      language: (json['language_code'] ?? json['language'])?.toString(),
      releaseDate: json['release_date']?.toString(),
      lyricsUrl: json['lyrics_url'] as String?,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      playCount: (json['play_count'] as num?)?.toInt() ?? 0,
      isExplicit: json['is_explicit'] == true,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      popularityScore: (json['popularity_score'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(
        json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      videoUrl: json['video_url'] as String?,
      isPublished: json['is_published'] == true,
      artists: artistsList,
      audios: audiosList,
    );
  }
}
