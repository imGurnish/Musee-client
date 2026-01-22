import 'package:hive/hive.dart';

part 'cached_track.g.dart';

/// Hive type adapter for caching track metadata locally.
/// Enables offline browsing and playback of previously played tracks.
@HiveType(typeId: 0)
class CachedTrack extends HiveObject {
  @HiveField(0)
  late String trackId;

  @HiveField(1)
  late String title;

  @HiveField(2)
  String? albumId;

  @HiveField(3)
  String? albumTitle;

  @HiveField(4)
  String? albumCoverUrl;

  @HiveField(5)
  late String artistName; // comma-separated artist names

  @HiveField(6)
  late int durationSeconds;

  @HiveField(7)
  late bool isExplicit;

  /// Local file path when audio is downloaded, null otherwise
  @HiveField(8)
  String? localAudioPath;

  /// Remote streaming URL (cached to avoid API calls)
  @HiveField(9)
  String? streamingUrl;

  /// Timestamp when this track was first cached
  @HiveField(10)
  late DateTime cachedAt;

  /// Timestamp when this track was last played (for LRU eviction)
  @HiveField(11)
  DateTime? lastPlayedAt;

  /// Size of cached audio file in bytes (0 if not downloaded)
  @HiveField(12)
  int audioSizeBytes = 0;
}

/// Hive type adapter for caching album metadata locally.
@HiveType(typeId: 1)
class CachedAlbum extends HiveObject {
  @HiveField(0)
  late String albumId;

  @HiveField(1)
  late String title;

  @HiveField(2)
  String? coverUrl;

  @HiveField(3)
  String? releaseDate;

  @HiveField(4)
  late String artistName; // primary artist

  /// List of track IDs for quick lookup
  @HiveField(5)
  late List<String> trackIds;

  /// Timestamp when this album was cached
  @HiveField(6)
  late DateTime cachedAt;
}
