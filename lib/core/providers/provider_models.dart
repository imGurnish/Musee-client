/// Unified models for music providers.
/// Since the app now exclusively uses the JioSaavn external API,
/// source tracking is simplified but retained for future extensibility.

library;

import 'package:equatable/equatable.dart';

/// Enum to identify the source of music content
enum MusicSource {
  external, // External music API (JioSaavn)
}

/// Extension to parse source from track IDs.
/// With single-source architecture, IDs are plain without prefixes.
/// Legacy "external:" prefixes are still handled for backward compatibility
/// with cached data.
extension MusicSourceParsing on String {
  MusicSource get musicSource => MusicSource.external;

  /// Strip any legacy 'external:' prefix to get the raw ID
  String get rawId {
    if (startsWith('external:')) return substring(9);
    return this;
  }

  /// Add source prefix (for backward compatibility with cached data)
  String prefixedId(MusicSource source) {
    if (startsWith('external:')) return this;
    return 'external:$this';
  }
}

/// Unified artist model from any music source
class ProviderArtist extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final MusicSource source;
  final String? bio;

  const ProviderArtist({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.source = MusicSource.external,
    this.bio,
  });

  /// Full ID with source prefix for unique identification
  String get prefixedId => id.prefixedId(source);

  @override
  List<Object?> get props => [id, name, avatarUrl, source, bio];
}

/// Unified album model from any music source
class ProviderAlbum extends Equatable {
  final String id;
  final String title;
  final String? coverUrl;
  final MusicSource source;
  final String? year;
  final List<ProviderArtist> artists;
  final List<ProviderTrack>? tracks; // null if not loaded

  const ProviderAlbum({
    required this.id,
    required this.title,
    this.coverUrl,
    this.source = MusicSource.external,
    this.year,
    this.artists = const [],
    this.tracks,
  });

  /// Full ID with source prefix for unique identification
  String get prefixedId => id.prefixedId(source);

  /// Primary artist name (comma-separated if multiple)
  String get artistName => artists.map((a) => a.name).join(', ');

  @override
  List<Object?> get props => [
    id,
    title,
    coverUrl,
    source,
    year,
    artists,
    tracks,
  ];
}

/// Unified track model from any music source
class ProviderTrack extends Equatable {
  final String id;
  final String title;
  final String? imageUrl;
  final MusicSource source;
  final int? durationSeconds;
  final bool isExplicit;
  final List<ProviderArtist> artists;
  final String? albumId;
  final String? albumTitle;

  const ProviderTrack({
    required this.id,
    required this.title,
    this.imageUrl,
    this.source = MusicSource.external,
    this.durationSeconds,
    this.isExplicit = false,
    this.artists = const [],
    this.albumId,
    this.albumTitle,
  });

  /// Full ID with source prefix for unique identification
  String get prefixedId => id.prefixedId(source);

  /// Primary artist name (comma-separated if multiple)
  String get artistName => artists.isEmpty
      ? 'Unknown Artist'
      : artists.map((a) => a.name).join(', ');

  @override
  List<Object?> get props => [
    id,
    title,
    imageUrl,
    source,
    durationSeconds,
    isExplicit,
    artists,
    albumId,
    albumTitle,
  ];
}

/// Unified playlist model from any music source
class ProviderPlaylist extends Equatable {
  final String id;
  final String title;
  final String? imageUrl;
  final MusicSource source;
  final String? description;
  final List<ProviderTrack>? tracks;

  const ProviderPlaylist({
    required this.id,
    required this.title,
    this.imageUrl,
    this.source = MusicSource.external,
    this.description,
    this.tracks,
  });

  /// Full ID with source prefix for unique identification
  String get prefixedId => id.prefixedId(source);

  @override
  List<Object?> get props => [id, title, imageUrl, source, description, tracks];
}

/// Search results aggregated from one or more providers
class ProviderSearchResults extends Equatable {
  final List<ProviderTrack> tracks;
  final List<ProviderAlbum> albums;
  final List<ProviderArtist> artists;

  const ProviderSearchResults({
    this.tracks = const [],
    this.albums = const [],
    this.artists = const [],
  });

  bool get isEmpty => tracks.isEmpty && albums.isEmpty && artists.isEmpty;

  /// Merge results from multiple providers
  ProviderSearchResults merge(ProviderSearchResults other) {
    return ProviderSearchResults(
      tracks: [...tracks, ...other.tracks],
      albums: [...albums, ...other.albums],
      artists: [...artists, ...other.artists],
    );
  }

  @override
  List<Object?> get props => [tracks, albums, artists];
}
