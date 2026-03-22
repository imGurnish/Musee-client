/// Music provider implementation wrapping the external music API.
/// This provider is DISABLED on web platform due to CORS restrictions.

library;

import 'package:flutter/foundation.dart';
import 'package:musee/features/search/data/datasources/external_music_data_source.dart';

import 'music_provider.dart';
import 'provider_models.dart';

/// External music API provider implementation.
/// Wraps the existing ExternalMusicDataSource for unified access.
///
/// **Important**: This provider returns `isAvailableOnPlatform = false` on web
/// to avoid CORS errors. The UI should check this before calling provider methods.
class ExternalMusicProvider extends MusicProvider {
  final ExternalMusicDataSource _dataSource;

  ExternalMusicProvider({ExternalMusicDataSource? dataSource})
    : _dataSource = dataSource ?? ExternalMusicDataSource();

  @override
  String get providerId => 'external';

  @override
  String get displayName => 'Music Library';

  @override
  MusicSource get source => MusicSource.external;

  /// Returns false on web platform to avoid CORS errors.
  @override
  bool get isAvailableOnPlatform => !kIsWeb;

  @override
  Future<ProviderTrack?> getTrack(String trackId) async {
    if (!isAvailableOnPlatform) return null;

    try {
      final song = await _dataSource.getSongById(trackId);
      if (song == null) return null;
      return _mapSongDetailToTrack(song);
    } catch (e) {
      if (kDebugMode) print('[ExternalMusicProvider] getTrack error: $e');
      return null;
    }
  }

  @override
  Future<ProviderAlbum?> getAlbum(String albumId) async {
    if (!isAvailableOnPlatform) return null;

    try {
      final album = await _dataSource.getAlbumDetails(albumId);
      if (album == null) return null;
      return _mapAlbumDetailToAlbum(album, includeTracks: false);
    } catch (e) {
      if (kDebugMode) print('[ExternalMusicProvider] getAlbum error: $e');
      return null;
    }
  }

  @override
  Future<ProviderAlbum?> getAlbumWithTracks(String albumId) async {
    if (!isAvailableOnPlatform) return null;

    try {
      final album = await _dataSource.getAlbumDetails(albumId);
      if (album == null) return null;
      return _mapAlbumDetailToAlbum(album, includeTracks: true);
    } catch (e) {
      if (kDebugMode) {
        print('[ExternalMusicProvider] getAlbumWithTracks error: $e');
      }
      return null;
    }
  }

  @override
  Future<ProviderArtist?> getArtist(String artistId) async {
    // External API doesn't have a direct artist lookup endpoint
    // This would require a search or a different API call
    if (!isAvailableOnPlatform) return null;
    return null;
  }

  @override
  Future<String?> getStreamUrl(String trackId) async {
    if (!isAvailableOnPlatform) return null;

    try {
      final song = await _dataSource.getSongById(trackId);
      if (song == null) return null;
      return _dataSource.getPlayableUrl(song);
    } catch (e) {
      if (kDebugMode) print('[ExternalMusicProvider] getStreamUrl error: $e');
      return null;
    }
  }

  @override
  Future<ProviderSearchResults> search(String query, {int limit = 20}) async {
    if (!isAvailableOnPlatform) {
      return const ProviderSearchResults();
    }

    try {
      final result = await _dataSource.search(query);
      if (result.isEmpty) {
        return const ProviderSearchResults();
      }

      final tracks = result.songs.take(limit).map(_mapSongToTrack).toList();
      final albums = result.albums.take(limit).map(_mapAlbumToAlbum).toList();
      final artists = result.artists
          .take(limit)
          .map(_mapArtistToArtist)
          .toList();

      return ProviderSearchResults(
        tracks: tracks,
        albums: albums,
        artists: artists,
      );
    } catch (e) {
      if (kDebugMode) print('[ExternalMusicProvider] search error: $e');
      return const ProviderSearchResults();
    }
  }

  @override
  Future<List<ProviderTrack>> getSongSuggestions(
    String trackId, {
    int limit = 10,
  }) async {
    if (!isAvailableOnPlatform) return const [];

    try {
      final suggestions = await _dataSource.getSongSuggestions(
        trackId,
        limit: limit,
      );
      return suggestions.map(_mapSongDetailToTrack).toList();
    } catch (e) {
      if (kDebugMode) {
        print('[ExternalMusicProvider] getSongSuggestions error: $e');
      }
      return const [];
    }
  }

  // --- Mapping Helpers ---

  ProviderTrack _mapSongToTrack(ExternalMusicSong song) {
    return ProviderTrack(
      id: song.id,
      title: song.title,
      imageUrl: song.imageUrl,
      source: MusicSource.external,
      durationSeconds: song.duration,
      artists: song.primaryArtists != null
          ? [
              ProviderArtist(
                id: 'artist',
                name: song.primaryArtists!,
                source: MusicSource.external,
              ),
            ]
          : const [],
      albumTitle: song.album,
    );
  }

  ProviderTrack _mapSongDetailToTrack(ExternalMusicSongDetail song) {
    return ProviderTrack(
      id: song.id,
      title: song.title,
      imageUrl: song.imageUrl,
      source: MusicSource.external,
      durationSeconds: song.duration,
      artists: song.primaryArtists != null
          ? [
              ProviderArtist(
                id: 'artist',
                name: song.primaryArtists!,
                source: MusicSource.external,
              ),
            ]
          : const [],
      albumTitle: song.album,
    );
  }

  ProviderAlbum _mapAlbumToAlbum(ExternalMusicAlbum album) {
    return ProviderAlbum(
      id: album.id,
      title: album.title,
      coverUrl: album.imageUrl,
      source: MusicSource.external,
      year: album.year,
      artists: album.music != null
          ? [
              ProviderArtist(
                id: 'artist',
                name: album.music!,
                source: MusicSource.external,
              ),
            ]
          : const [],
    );
  }

  ProviderAlbum _mapAlbumDetailToAlbum(
    ExternalMusicAlbumDetail album, {
    required bool includeTracks,
  }) {
    return ProviderAlbum(
      id: album.id,
      title: album.title,
      coverUrl: album.imageUrl,
      source: MusicSource.external,
      year: album.year,
      artists: album.primaryArtists != null
          ? [
              ProviderArtist(
                id: 'artist',
                name: album.primaryArtists!,
                source: MusicSource.external,
              ),
            ]
          : const [],
      tracks: includeTracks
          ? album.songs.map(_mapSongDetailToTrack).toList()
          : null,
    );
  }

  ProviderArtist _mapArtistToArtist(ExternalMusicArtist artist) {
    return ProviderArtist(
      id: artist.id,
      name: artist.name,
      avatarUrl: artist.imageUrl,
      source: MusicSource.external,
    );
  }
}
