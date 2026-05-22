import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/search/data/models/suggestion_model.dart';
import 'package:musee/features/search/data/models/catalog_search_models.dart';
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
    String? type,
    int? limit,
    int? page,
  });
}

class SearchRemoteDataSourceImpl implements SearchRemoteDataSource {
  final SupabaseClient supabaseClient;

  SearchRemoteDataSourceImpl(this.supabaseClient);

  @override
  Session? get currentSession => supabaseClient.auth.currentSession;

  @override
  Future<List<SuggestionModel>> getSuggestions(String query) async {
    try {
      // Get suggestions from backend API
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
        Uri.parse(
          '${AppSecrets.backendUrl}/api/playlists/search?page=0&limit=5&q=$q',
        ),
      ];

      final backendResponses = await Future.wait(
        backendUris.map(
          (u) => http
              .get(u, headers: headers)
              .timeout(const Duration(seconds: 10)),
        ),
      );

      final suggestions = <String>{};

      // Process Backend Results
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

      // Playlists
      if (backendResponses.length > 3 &&
          backendResponses[3].statusCode == 200) {
        final data = json.decode(backendResponses[3].body);
        final items = _extractItems(data);
        for (final it in items) {
          final m = (it as Map).cast<String, dynamic>();
          final name = m['name']?.toString();
          final title = m['title']?.toString();
          final value = (name != null && name.isNotEmpty) ? name : title;
          if (value != null && value.isNotEmpty) suggestions.add(value);
        }
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
    String? type,
    int? limit,
    int? page,
  }) async {
    try {
      final token = currentSession?.accessToken;
      final Map<String, String> headers = token != null
          ? {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            }
          : {'Content-Type': 'application/json'};

      final q = Uri.encodeQueryComponent(query);

      // Build unified query URL
      final typeParam = type != null ? '&type=$type' : '';
      final limitParam = limit != null ? '&limit=$limit' : '';
      final pageParam = page != null ? '&page=$page' : '';

      final url = Uri.parse(
        '${AppSecrets.backendUrl}/api/user/search?q=$q$typeParam$limitParam$pageParam',
      );

      if (kDebugMode) {
        print('Searching catalog with unified URL: $url');
      }

      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print('SearchCatalog status code error: ${response.statusCode} - ${response.body}');
        }
        return const CatalogSearchResults();
      }

      final Map<String, dynamic> data = json.decode(response.body);

      final List<dynamic> tracks = data['tracks'] is List ? data['tracks'] : const [];
      final List<dynamic> albums = data['albums'] is List ? data['albums'] : const [];
      final List<dynamic> artists = data['artists'] is List ? data['artists'] : const [];
      final List<dynamic> playlists = data['playlists'] is List ? data['playlists'] : const [];

      return CatalogSearchResultsModel.fromThreeLists(
        tracks: tracks,
        albums: albums,
        artists: artists,
        playlists: playlists,
      );
    } catch (e) {
      if (kDebugMode) print('Catalog search exception: $e');
      return const CatalogSearchResults();
    }
  }

  /// Search External API and convert results to CatalogSearchResults.
  /// REMOVED - External music sources are no longer supported.
  
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
