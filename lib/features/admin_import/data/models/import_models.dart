// Models for Jio Saavn Import Feature

class JioTrackModel {
  final String id;
  final String title;
  final List<JioArtistModel> artists;
  final JioAlbumModel album;
  final int duration;
  final String language;
  final int year;
  final bool explicit;
  final String? downloadUrl;
  final List<JioArtistModel> primaryArtist;

  const JioTrackModel({
    required this.id,
    required this.title,
    required this.artists,
    required this.album,
    required this.duration,
    required this.language,
    required this.year,
    required this.explicit,
    this.downloadUrl,
    required this.primaryArtist,
  });

  factory JioTrackModel.fromJson(Map<String, dynamic> json) {
    return JioTrackModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artists: (json['artists'] as List?)
              ?.map((a) => JioArtistModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      album: JioAlbumModel.fromJson(json['album'] as Map<String, dynamic>? ?? {}),
      duration: json['duration'] as int? ?? 0,
      language: json['language'] as String? ?? 'en',
      year: json['year'] as int? ?? DateTime.now().year,
      explicit: json['explicit'] as bool? ?? false,
      downloadUrl: json['downloadUrl'] as String?,
      primaryArtist: (json['primaryArtist'] as List?)
              ?.map((a) => JioArtistModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class JioArtistModel {
  final String? id;
  final String name;
  final String? image;
  final String? bio;
  final String? language;
  final String role;

  const JioArtistModel({
    this.id,
    required this.name,
    this.image,
    this.bio,
    this.language,
    this.role = 'primary',
  });

  factory JioArtistModel.fromJson(Map<String, dynamic> json) {
    return JioArtistModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      image: json['image'] as String?,
      bio: json['bio'] as String?,
      language: json['language'] as String?,
      role: json['role'] as String? ?? 'primary',
    );
  }
}

class JioAlbumModel {
  final String id;
  final String title;
  final List<JioArtistModel> artists;
  final String? image;
  final int year;
  final String language;
  final String? releaseDate;
  final String? description;
  final List<JioTrackModel> tracks;
  final int songCount;

  const JioAlbumModel({
    required this.id,
    required this.title,
    required this.artists,
    this.image,
    required this.year,
    required this.language,
    this.releaseDate,
    this.description,
    required this.tracks,
    required this.songCount,
  });

  factory JioAlbumModel.fromJson(Map<String, dynamic> json) {
    return JioAlbumModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      artists: (json['artists'] as List?)
              ?.map((a) => JioArtistModel.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      image: json['image'] as String?,
      year: json['year'] as int? ?? DateTime.now().year,
      language: json['language'] as String? ?? 'en',
      releaseDate: json['releaseDate'] as String?,
      description: json['description'] as String?,
      tracks: (json['tracks'] as List?)
              ?.map((t) => JioTrackModel.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      songCount: json['songCount'] as int? ?? 0,
    );
  }
}

class ImportProgressModel {
  final String sessionId;
  final String status; // pending, progress, success, failed
  final int totalTracks;
  final int importedTracks;
  final int failedTracks;
  final String? errorMessage;
  final Map<String, dynamic>? transaction;
  final DateTime timestamp;

  const ImportProgressModel({
    required this.sessionId,
    required this.status,
    required this.totalTracks,
    required this.importedTracks,
    required this.failedTracks,
    this.errorMessage,
    this.transaction,
    required this.timestamp,
  });

  double get progress => totalTracks > 0 ? importedTracks / totalTracks : 0.0;

  factory ImportProgressModel.initial(String sessionId, int totalTracks) {
    return ImportProgressModel(
      sessionId: sessionId,
      status: 'pending',
      totalTracks: totalTracks,
      importedTracks: 0,
      failedTracks: 0,
      timestamp: DateTime.now(),
    );
  }

  ImportProgressModel copyWith({
    String? status,
    int? importedTracks,
    int? failedTracks,
    String? errorMessage,
    Map<String, dynamic>? transaction,
  }) {
    return ImportProgressModel(
      sessionId: sessionId,
      status: status ?? this.status,
      totalTracks: totalTracks,
      importedTracks: importedTracks ?? this.importedTracks,
      failedTracks: failedTracks ?? this.failedTracks,
      errorMessage: errorMessage ?? this.errorMessage,
      transaction: transaction ?? this.transaction,
      timestamp: DateTime.now(),
    );
  }
}

class ImportSessionModel {
  final String id;
  final String albumTitle;
  final String artistName;
  final int trackCount;
  final bool isPublished;
  final bool isDryRun;
  final ImportProgressModel progress;
  final DateTime createdAt;

  const ImportSessionModel({
    required this.id,
    required this.albumTitle,
    required this.artistName,
    required this.trackCount,
    required this.isPublished,
    required this.isDryRun,
    required this.progress,
    required this.createdAt,
  });
}
