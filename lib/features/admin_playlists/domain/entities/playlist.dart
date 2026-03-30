class PlaylistTrack {
  final String trackId;
  final String title;
  final int duration;
  final DateTime createdAt;

  PlaylistTrack({
    required this.trackId,
    required this.title,
    required this.duration,
    required this.createdAt,
  });
}

class Playlist {
  final String playlistId;
  final String name;
  final String? description;
  final String? coverUrl;
  final String? language;
  final bool isPublic;
  final int likesCount;
  final int totalTracks;
  final int? duration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PlaylistTrack>? tracks;

  Playlist({
    required this.playlistId,
    required this.name,
    this.description,
    this.coverUrl,
    this.language,
    required this.isPublic,
    required this.likesCount,
    required this.totalTracks,
    this.duration,
    required this.createdAt,
    required this.updatedAt,
    this.tracks,
  });

  Playlist copyWith({
    String? playlistId,
    String? name,
    String? description,
    String? coverUrl,
    String? language,
    bool? isPublic,
    int? likesCount,
    int? totalTracks,
    int? duration,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<PlaylistTrack>? tracks,
  }) {
    return Playlist(
      playlistId: playlistId ?? this.playlistId,
      name: name ?? this.name,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      language: language ?? this.language,
      isPublic: isPublic ?? this.isPublic,
      likesCount: likesCount ?? this.likesCount,
      totalTracks: totalTracks ?? this.totalTracks,
      duration: duration ?? this.duration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tracks: tracks ?? this.tracks,
    );
  }
}
