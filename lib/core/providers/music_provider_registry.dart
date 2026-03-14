/// Registry for managing music providers.
/// With single-source architecture (JioSaavn), this provides a unified
/// access layer that can be extended to support additional sources in the future.

library;

import 'package:flutter/foundation.dart';

import 'music_provider.dart';
import 'provider_models.dart';

/// Central registry managing all music providers.
///
/// Usage:
/// ```dart
/// final registry = MusicProviderRegistry([
///   ExternalMusicProvider(),
/// ]);
///
/// // Get stream URL for any track
/// final url = await registry.getStreamUrl('12345');
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

  /// Get a provider by its ID
  MusicProvider? getProviderById(String providerId) {
    try {
      return _providers.firstWhere((p) => p.providerId == providerId);
    } catch (e) {
      return null;
    }
  }

  /// Get the provider for a track. With single-source, always returns
  /// the external provider.
  MusicProvider? getProviderForTrack(String trackId) {
    if (_providers.isEmpty) return null;
    // Always use the first available provider (external/JioSaavn)
    return activeProviders.isNotEmpty ? activeProviders.first : _providers.first;
  }

  /// Get download URL for a track.
  Future<String?> getDownloadUrl(String trackId) async {
    final provider = getProviderForTrack(trackId);
    if (provider == null) return null;
    final rawId = trackId.rawId;
    return provider.getDownloadUrl(rawId);
  }

  /// Get streaming URL for a track.
  Future<String?> getStreamUrl(String trackId) async {
    final provider = getProviderForTrack(trackId);
    if (provider == null) return null;
    final rawId = trackId.rawId;
    return provider.getStreamUrl(rawId);
  }

  /// Get track details.
  Future<ProviderTrack?> getTrack(String trackId) async {
    final provider = getProviderForTrack(trackId);
    if (provider == null) return null;
    final rawId = trackId.rawId;
    return provider.getTrack(rawId);
  }

  /// Get album details.
  Future<ProviderAlbum?> getAlbum(String albumId) async {
    final provider = getProviderForTrack(albumId);
    if (provider == null) return null;
    final rawId = albumId.rawId;
    return provider.getAlbum(rawId);
  }

  /// Get album with tracks.
  Future<ProviderAlbum?> getAlbumWithTracks(String albumId) async {
    final provider = getProviderForTrack(albumId);
    if (provider == null) return null;
    final rawId = albumId.rawId;
    return provider.getAlbumWithTracks(rawId);
  }

  /// Get artist details.
  Future<ProviderArtist?> getArtist(String artistId) async {
    final provider = getProviderForTrack(artistId);
    if (provider == null) return null;
    final rawId = artistId.rawId;
    return provider.getArtist(rawId);
  }

  /// Search across all active providers and aggregate results.
  Future<ProviderSearchResults> search(
    String query, {
    int limitPerProvider = 10,
  }) async {
    final results = await Future.wait(
      activeProviders.map(
        (p) => p.search(query, limit: limitPerProvider).catchError((_) {
          if (kDebugMode) {
            print('[MusicProviderRegistry] Search failed for ${p.providerId}');
          }
          return const ProviderSearchResults();
        }),
      ),
    );

    // Merge all results
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
