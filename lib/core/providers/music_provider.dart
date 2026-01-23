/// Abstract interface defining the contract for any music data provider.
/// Implementing this interface allows seamless integration of different
/// music sources (Musee server, external APIs, etc.) following the Strategy Pattern.

library;

import 'provider_models.dart';

/// Abstract music provider interface following clean architecture principles.
/// Each music source (Musee server, external API) implements this.
abstract class MusicProvider {
  /// Unique identifier for this provider (e.g., 'musee', 'external')
  String get providerId;

  /// Human-readable display name
  String get displayName;

  /// The source type for content from this provider
  MusicSource get source;

  /// Whether this provider is available on the current platform.
  /// For example, external API is disabled on web due to CORS issues.
  bool get isAvailableOnPlatform;

  /// Get a single track by its raw ID (without source prefix)
  Future<ProviderTrack?> getTrack(String trackId);

  /// Get a single album by its raw ID (without source prefix)
  Future<ProviderAlbum?> getAlbum(String albumId);

  /// Get album with full track listing
  Future<ProviderAlbum?> getAlbumWithTracks(String albumId);

  /// Get a single artist by their raw ID (without source prefix)
  Future<ProviderArtist?> getArtist(String artistId);

  /// Get the streaming URL for a track
  /// Returns null if track is not streamable or an error occurs
  Future<String?> getStreamUrl(String trackId);

  /// Get the download URL for a track (e.g. mp3 file)
  /// Guaranteed to return a directly downloadable file, unlike getStreamUrl which might return HLS.
  Future<String?> getDownloadUrl(String trackId) async {
    // Default implementation falls back to getStreamUrl
    return getStreamUrl(trackId);
  }

  /// Search for content across tracks, albums, and artists
  Future<ProviderSearchResults> search(String query, {int limit = 20});

  /// Get recommended/trending tracks (if supported by provider)
  Future<List<ProviderTrack>> getTrendingTracks({int limit = 20}) async {
    return const [];
  }

  /// Get new releases (if supported by provider)
  Future<List<ProviderAlbum>> getNewReleases({int limit = 20}) async {
    return const [];
  }
}

/// Result of attempting to get a streaming URL
class StreamUrlResult {
  final String? url;
  final String? error;
  final bool requiresAuth;

  const StreamUrlResult({this.url, this.error, this.requiresAuth = false});

  bool get isSuccess => url != null && url!.isNotEmpty;
  bool get isError => error != null;

  factory StreamUrlResult.success(String url) => StreamUrlResult(url: url);
  factory StreamUrlResult.error(String message) =>
      StreamUrlResult(error: message);
  factory StreamUrlResult.authRequired() => const StreamUrlResult(
    requiresAuth: true,
    error: 'Authentication required',
  );
}
