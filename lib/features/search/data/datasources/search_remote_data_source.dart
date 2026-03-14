import 'package:musee/features/search/data/models/suggestion_model.dart';
import 'package:musee/features/search/data/models/catalog_search_models.dart';
import 'package:musee/features/search/data/datasources/external_music_data_source.dart';
import 'package:musee/features/search/domain/entities/catalog_search.dart';
import 'package:flutter/foundation.dart';

abstract interface class SearchRemoteDataSource {
  Future<List<SuggestionModel>> getSuggestions(String query);
  Future<CatalogSearchResults> searchCatalog(
    String query, {
    int perSectionLimit = 5,
  });
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final ExternalMusicDataSource _externalMusicDataSource =
      ExternalMusicDataSource();

  SearchRemoteDataSourceImpl();

  @override
  Future<List<SuggestionModel>> getSuggestions(String query) async {
    try {
      final externalResult = await _externalMusicDataSource.search(query);

      final suggestions = <String>{};

      // Process External (JioSaavn) Results
      for (final song in externalResult.songs.take(6)) {
        suggestions.add(song.title);
      }
      for (final album in externalResult.albums.take(3)) {
        suggestions.add(album.title);
      }
      for (final artist in externalResult.artists.take(3)) {
        suggestions.add(artist.name);
      }

      if (suggestions.isNotEmpty) {
        return suggestions
            .take(15)
            .map((s) => SuggestionModel.fromJson(s))
            .toList();
      }
      return _getFallbackSuggestions(query);
    } catch (e) {
      if (kDebugMode) print('GetSuggestions error: $e');
      return _getFallbackSuggestions(query);
    }
  }

  List<SuggestionModel> _getFallbackSuggestions(String query) {
    if (query.isEmpty) return [];

    // Generate intelligent fallback suggestions
    final suggestions = [
      '$query song',
      '$query music',
      '$query video',
      '$query tutorial',
      '$query movies',
      '$query dance',
      '$query new',
      '$query latest',
    ];

    return suggestions.map((s) => SuggestionModel.fromJson(s)).toList();
  }

  @override
  Future<CatalogSearchResults> searchCatalog(
    String query, {
    int perSectionLimit = 5,
  }) async {
    // Search only via JioSaavn external API
    return _searchExternal(query, perSectionLimit: perSectionLimit);
  }

  /// Search External (JioSaavn) API and convert results to CatalogSearchResults.
  Future<CatalogSearchResults> _searchExternal(
    String query, {
    int perSectionLimit = 5,
  }) async {
    try {
      final result = await _externalMusicDataSource.search(query);
      if (result.isEmpty) {
        return const CatalogSearchResults();
      }

      // Convert External results to catalog entities
      final tracks = result.songs.take(perSectionLimit).map((song) {
        return CatalogTrackModel(
          trackId: 'external:${song.id}',
          title: song.title,
          duration: song.duration,
          imageUrl: song.imageUrl,
          source: SearchSource.external,
          artists: song.primaryArtists != null
              ? [
                  CatalogArtistModel(
                    artistId: 'external:artist',
                    name: song.primaryArtists,
                    source: SearchSource.external,
                  ),
                ]
              : const [],
        );
      }).toList();

      final albums = result.albums.take(perSectionLimit).map((album) {
        return CatalogAlbumModel(
          albumId: 'external:${album.id}',
          title: album.title,
          coverUrl: album.imageUrl,
          source: SearchSource.external,
          artists: album.music != null
              ? [
                  CatalogArtistModel(
                    artistId: 'external:artist',
                    name: album.music,
                    source: SearchSource.external,
                  ),
                ]
              : const [],
        );
      }).toList();

      final artists = result.artists.take(perSectionLimit).map((artist) {
        return CatalogArtistModel(
          artistId: 'external:${artist.id}',
          name: artist.name,
          avatarUrl: artist.imageUrl,
          source: SearchSource.external,
        );
      }).toList();

      return CatalogSearchResults(
        tracks: tracks,
        albums: albums,
        artists: artists,
      );
    } catch (e) {
      if (kDebugMode) print('External search exception: $e');
      return const CatalogSearchResults();
    }
  }
}
