/// Registry for managing multiple music providers.
/// Provides unified access to all available music sources and handles
/// provider selection based on track IDs and platform availability.

import 'package:flutter/foundation.dart';

import 'music_provider.dart';
import 'provider_models.dart';
import 'musee_server_provider.dart';
import 'external_music_provider.dart';

/// Central registry managing all music providers.
///
/// Usage:
/// ```dart
/// final registry = MusicProviderRegistry([
///   MuseeServerProvider(supabase),
///   ExternalMusicProvider(),
/// ]);
///
/// // Get stream URL for any track (auto-selects correct provider)
/// final url = await registry.getStreamUrl('external:12345');
///
/// // Search across all active providers
/// final results = await registry.search('query');
/// ```
class MusicProviderRegistry {
  final List<MusicProvider> _providers;

  MusicProviderRegistry(this._providers);

  /// All registered providers, regardless of platform availability
  List<MusicProvider> get allProviders => List.unmodifiable(_providers);

  /// Providers available on the current platform
  List<MusicProvider> get activeProviders =>
      _providers.where((p) => p.isAvailableOnPlatform).toList();

  /// Get a provider by its ID ('musee', 'external', etc.)
  MusicProvider? getProviderById(String providerId) {
    try {
      return _providers.firstWhere((p) => p.providerId == providerId);
    } catch (e) {
      return null;
    }
  }

  /// Determine which provider should handle a track based on its ID.
  /// Track IDs with 'external:' prefix go to ExternalMusicProvider.
  MusicProvider? getProviderForTrack(String trackId) {
    final source = trackId.musicSource;
    final providerId = source == MusicSource.external ? 'external' : 'musee';
    final provider = getProviderById(providerId);

    // Fall back to musee if the requested provider isn't available
    if (provider == null || !provider.isAvailableOnPlatform) {
      return getProviderById('musee');
    }
    return provider;
  }

  /// Get streaming URL for a track, automatically selecting the correct provider.
  Future<String?> getStreamUrl(String trackId) async {
    final provider = getProviderForTrack(trackId);
    if (provider == null) return null;

    // Strip the source prefix to get the raw ID
    final rawId = trackId.rawId;
    return provider.getStreamUrl(rawId);
  }

  /// Get track details, automatically selecting the correct provider.
  Future<ProviderTrack?> getTrack(String trackId) async {
    final provider = getProviderForTrack(trackId);
    if (provider == null) return null;

    final rawId = trackId.rawId;
    return provider.getTrack(rawId);
  }

  /// Get album details, automatically selecting the correct provider.
  Future<ProviderAlbum?> getAlbum(String albumId) async {
    final provider = getProviderForTrack(albumId);
    if (provider == null) return null;

    final rawId = albumId.rawId;
    return provider.getAlbum(rawId);
  }

  /// Get album with tracks, automatically selecting the correct provider.
  Future<ProviderAlbum?> getAlbumWithTracks(String albumId) async {
    final provider = getProviderForTrack(albumId);
    if (provider == null) return null;

    final rawId = albumId.rawId;
    return provider.getAlbumWithTracks(rawId);
  }

  /// Get artist details, automatically selecting the correct provider.
  Future<ProviderArtist?> getArtist(String artistId) async {
    final provider = getProviderForTrack(artistId);
    if (provider == null) return null;

    final rawId = artistId.rawId;
    return provider.getArtist(rawId);
  }

  /// Search across all active providers and aggregate results.
  /// Results from the primary provider (Musee) appear first.
  Future<ProviderSearchResults> search(
    String query, {
    int limitPerProvider = 10,
  }) async {
    final results = await Future.wait(
      activeProviders.map(
        (p) => p.search(query, limit: limitPerProvider).catchError((_) {
          if (kDebugMode)
            print('[MusicProviderRegistry] Search failed for ${p.providerId}');
          return const ProviderSearchResults();
        }),
      ),
    );

    // Merge all results, starting with empty
    var merged = const ProviderSearchResults();
    for (final result in results) {
      merged = merged.merge(result);
    }
    return merged;
  }

  /// Get trending tracks from all active providers.
  Future<List<ProviderTrack>> getTrendingTracks({
    int limitPerProvider = 10,
  }) async {
    final results = await Future.wait(
      activeProviders.map(
        (p) => p.getTrendingTracks(limit: limitPerProvider).catchError((_) {
          return <ProviderTrack>[];
        }),
      ),
    );
    return results.expand((list) => list).toList();
  }

  /// Get new releases from all active providers.
  Future<List<ProviderAlbum>> getNewReleases({
    int limitPerProvider = 10,
  }) async {
    final results = await Future.wait(
      activeProviders.map(
        (p) => p.getNewReleases(limit: limitPerProvider).catchError((_) {
          return <ProviderAlbum>[];
        }),
      ),
    );
    return results.expand((list) => list).toList();
  }
}
