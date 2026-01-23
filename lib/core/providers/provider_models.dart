/// Unified models for music providers, enabling seamless integration
/// of multiple music sources (Musee server, external APIs) with source tracking.

library;

import 'package:equatable/equatable.dart';

/// Enum to identify the source of music content
enum MusicSource {
  musee, // Musee backend server
  external, // External music API (disabled on web due to CORS)
}

/// Extension to parse source from prefixed track IDs like "external:12345"
extension MusicSourceParsing on String {
  MusicSource get musicSource {
    if (startsWith('external:')) return MusicSource.external;
    return MusicSource.musee;
  }

  String get rawId {
    if (startsWith('external:')) return substring(9);
    return this;
  }

  String prefixedId(MusicSource source) {
    if (source == MusicSource.external) return 'external:$this';
    return this;
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
    required this.source,
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
    required this.source,
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
    required this.source,
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
    required this.source,
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
