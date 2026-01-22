import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/search/data/models/suggestion_model.dart';
import 'package:musee/features/search/data/models/catalog_search_models.dart';
import 'package:musee/features/search/data/datasources/external_music_data_source.dart';
import 'package:musee/features/search/domain/entities/catalog_search.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

abstract interface class SearchRemoteDataSource {
  Session? get currentSession;
  Future<List<SuggestionModel>> getSuggestions(String query);
  Future<CatalogSearchResults> searchCatalog(
    String query, {
    int perSectionLimit = 5,
  });
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final SupabaseClient supabaseClient;
  final ExternalMusicDataSource _externalMusicDataSource =
      ExternalMusicDataSource();

  SearchRemoteDataSourceImpl(this.supabaseClient);

  @override
  Session? get currentSession => supabaseClient.auth.currentSession;

  @override
  Future<List<SuggestionModel>> getSuggestions(String query) async {
    try {
      // Aggregate suggestions from backend and External API in parallel
      final token = currentSession?.accessToken;
      final Map<String, String> headers = token != null
          ? {'Authorization': 'Bearer $token'}
          : {};
      final q = Uri.encodeQueryComponent(query);

      final backendUris = [
        Uri.parse(
          '${AppSecrets.backendUrl}/api/user/tracks?page=0&limit=3&q=$q',
        ),
        Uri.parse(
          '${AppSecrets.backendUrl}/api/user/albums?page=0&limit=3&q=$q',
        ),
        Uri.parse(
          '${AppSecrets.backendUrl}/api/user/artists?page=0&limit=3&q=$q',
        ),
      ];

      // Launch backend and External searches in parallel
      final results = await Future.wait([
        Future.wait(
          backendUris.map(
            (u) => http
                .get(u, headers: headers)
                .timeout(const Duration(seconds: 10)),
          ),
        ),
        _externalMusicDataSource.search(query),
      ]);

      final backendResponses = results[0] as List<http.Response>;
      final externalResult = results[1] as ExternalMusicSearchResult;

      final suggestions = <String>{};

      // 1. Process Backend Results
      // Tracks
      if (backendResponses.isNotEmpty &&
          backendResponses[0].statusCode == 200) {
        final data = json.decode(backendResponses[0].body);
        final items = _extractItems(data);
        for (final it in items) {
          final m = (it as Map).cast<String, dynamic>();
          final title = m['title']?.toString();
          if (title != null && title.isNotEmpty) suggestions.add(title);
        }
      }

      // Albums
      if (backendResponses.length > 1 &&
          backendResponses[1].statusCode == 200) {
        final data = json.decode(backendResponses[1].body);
        final items = _extractItems(data);
        for (final it in items) {
          final m = (it as Map).cast<String, dynamic>();
          final title = m['title']?.toString();
          if (title != null && title.isNotEmpty) suggestions.add(title);
        }
      }

      // Artists
      if (backendResponses.length > 2 &&
          backendResponses[2].statusCode == 200) {
        final data = json.decode(backendResponses[2].body);
        final items = _extractItems(data);
        for (final it in items) {
          final m = (it as Map).cast<String, dynamic>();
          final name = m['name']?.toString();
          if (name != null && name.isNotEmpty) suggestions.add(name);
        }
      }

      // 2. Process External Results
      for (final song in externalResult.songs.take(4)) {
        suggestions.add(song.title);
      }
      for (final album in externalResult.albums.take(2)) {
        suggestions.add(album.title);
      }
      for (final artist in externalResult.artists.take(2)) {
        suggestions.add(artist.name);
      }

      if (suggestions.isNotEmpty) {
        return suggestions
            .take(15) // Increased limit to accommodate more sources
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
    // Run catalog search and External search in parallel
    final results = await Future.wait([
      _searchCatalogBackend(query, perSectionLimit: perSectionLimit),
      _searchExternal(query, perSectionLimit: perSectionLimit),
    ]);

    final catalogResults = results[0];
    final externalResults = results[1];

    // Merge results: catalog first, then External
    return catalogResults.merge(externalResults);
  }

  /// Search the backend catalog API.
  Future<CatalogSearchResults> _searchCatalogBackend(
    String query, {
    int perSectionLimit = 5,
  }) async {
    try {
      final token = currentSession?.accessToken;
      final Map<String, String> headers = token != null
          ? {'Authorization': 'Bearer $token'}
          : {};
      final q = Uri.encodeQueryComponent(query);
      final limit = perSectionLimit.clamp(1, 20);

      final tracksUri = Uri.parse(
        '${AppSecrets.backendUrl}/api/user/tracks?page=0&limit=$limit&q=$q',
      );
      final albumsUri = Uri.parse(
        '${AppSecrets.backendUrl}/api/user/albums?page=0&limit=$limit&q=$q',
      );
      final artistsUri = Uri.parse(
        '${AppSecrets.backendUrl}/api/user/artists?page=0&limit=$limit&q=$q',
      );

      final responses = await Future.wait(
        [
          http.get(tracksUri, headers: headers),
          http.get(albumsUri, headers: headers),
          http.get(artistsUri, headers: headers),
        ].map((f) => f.timeout(const Duration(seconds: 30))),
      );

      List<dynamic> tracks = const [];
      List<dynamic> albums = const [];
      List<dynamic> artists = const [];

      if (responses[0].statusCode == 200) {
        final obj = json.decode(responses[0].body);
        tracks = _extractItems(obj);
      }
      if (responses[1].statusCode == 200) {
        final obj = json.decode(responses[1].body);
        albums = _extractItems(obj);
      }
      if (responses[2].statusCode == 200) {
        final obj = json.decode(responses[2].body);
        artists = _extractItems(obj);
      }

      return CatalogSearchResultsModel.fromThreeLists(
        tracks: tracks,
        albums: albums,
        artists: artists,
      );
    } catch (e) {
      if (kDebugMode) print('Catalog search exception: $e');
      return const CatalogSearchResults();
    }
  }

  /// Search External API and convert results to CatalogSearchResults.
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

/// Extract a list of items from various common response envelopes.
List<dynamic> _extractItems(dynamic decoded) {
  if (decoded is List) return decoded;
  if (decoded is Map<String, dynamic>) {
    final map = decoded;
    final items = map['items'];
    if (items is List) return items;
    final data = map['data'];
    if (data is List) return data;
    final results = map['results'];
    if (results is List) return results;
  }
  return const [];
}
