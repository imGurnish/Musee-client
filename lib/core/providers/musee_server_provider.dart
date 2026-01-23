/// Music provider implementation for the Musee backend server.
/// Wraps existing API calls to the Musee server endpoints.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'music_provider.dart';
import 'provider_models.dart';

/// Musee backend server music provider implementation.
class MuseeServerProvider implements MusicProvider {
  final SupabaseClient _supabase;
  static const _timeout = Duration(seconds: 15);

  MuseeServerProvider(this._supabase);

  @override
  String get providerId => 'musee';

  @override
  String get displayName => 'Musee';

  @override
  MusicSource get source => MusicSource.musee;

  @override
  bool get isAvailableOnPlatform => true; // Always available

  Map<String, String> get _headers {
    final token = _supabase.auth.currentSession?.accessToken;
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String get _baseUrl => AppSecrets.backendUrl;

  @override
  Future<ProviderTrack?> getTrack(String trackId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/user/tracks/$trackId');
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseTrack(data);
    } catch (e) {
      if (kDebugMode) print('[MuseeServerProvider] getTrack error: $e');
      return null;
    }
  }

  @override
  Future<ProviderAlbum?> getAlbum(String albumId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/user/albums/$albumId');
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseAlbum(data);
    } catch (e) {
      if (kDebugMode) print('[MuseeServerProvider] getAlbum error: $e');
      return null;
    }
  }

  @override
  Future<ProviderAlbum?> getAlbumWithTracks(String albumId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/user/albums/$albumId?expand=tracks');
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseAlbum(data, includeTracks: true);
    } catch (e) {
      if (kDebugMode)
        print('[MuseeServerProvider] getAlbumWithTracks error: $e');
      return null;
    }
  }

  @override
  Future<ProviderArtist?> getArtist(String artistId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/user/artists/$artistId');
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _parseArtist(data);
    } catch (e) {
      if (kDebugMode) print('[MuseeServerProvider] getArtist error: $e');
      return null;
    }
  }

  @override
  Future<String?> getStreamUrl(String trackId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/user/tracks/$trackId');
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      final hls = data['hls'] as Map<String, dynamic>?;
      final master = hls?['master'] as String?;

      // On Windows/web, prefer MP3 fallback over HLS
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final audios = (data['audios'] as List?)?.cast<dynamic>() ?? const [];
        String? bestMp3;
        int bestBitrate = -1;
        for (final item in audios) {
          final m = (item as Map).cast<String, dynamic>();
          final ext = (m['ext'] as String?)?.toLowerCase();
          final path = m['path'] as String?;
          final br = (m['bitrate'] as num?)?.toInt() ?? 0;
          if (ext == 'mp3' && path != null && path.isNotEmpty) {
            if (br > bestBitrate) {
              bestBitrate = br;
              bestMp3 = path;
            }
          }
        }
        return bestMp3 ?? master;
      }

      return master;
    } catch (e) {
      if (kDebugMode) print('[MuseeServerProvider] getStreamUrl error: $e');
      return null;
    }
  }

  @override
  Future<ProviderSearchResults> search(String query, {int limit = 20}) async {
    try {
      final q = Uri.encodeQueryComponent(query);
      final uris = [
        Uri.parse('$_baseUrl/api/user/tracks?page=0&limit=$limit&q=$q'),
        Uri.parse('$_baseUrl/api/user/albums?page=0&limit=$limit&q=$q'),
        Uri.parse('$_baseUrl/api/user/artists?page=0&limit=$limit&q=$q'),
      ];

      final responses = await Future.wait(
        uris.map((u) => http.get(u, headers: _headers).timeout(_timeout)),
      );

      List<ProviderTrack> tracks = [];
      List<ProviderAlbum> albums = [];
      List<ProviderArtist> artists = [];

      // Parse tracks
      if (responses[0].statusCode == 200) {
        final data = json.decode(responses[0].body);
        final items = _extractItems(data);
        tracks = items
            .whereType<Map>()
            .map((e) => _parseTrack(e.cast<String, dynamic>()))
            .whereType<ProviderTrack>()
            .toList();
      }

      // Parse albums
      if (responses[1].statusCode == 200) {
        final data = json.decode(responses[1].body);
        final items = _extractItems(data);
        albums = items
            .whereType<Map>()
            .map((e) => _parseAlbum(e.cast<String, dynamic>()))
            .whereType<ProviderAlbum>()
            .toList();
      }

      // Parse artists
      if (responses[2].statusCode == 200) {
        final data = json.decode(responses[2].body);
        final items = _extractItems(data);
        artists = items
            .whereType<Map>()
            .map((e) => _parseArtist(e.cast<String, dynamic>()))
            .whereType<ProviderArtist>()
            .toList();
      }

      return ProviderSearchResults(
        tracks: tracks,
        albums: albums,
        artists: artists,
      );
    } catch (e) {
      if (kDebugMode) print('[MuseeServerProvider] search error: $e');
      return const ProviderSearchResults();
    }
  }

  @override
  Future<List<ProviderTrack>> getTrendingTracks({int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/user/dashboard/trending?page=0&limit=$limit',
      );
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return const [];

      final data = json.decode(response.body);
      final items = _extractItems(data);
      return items
          .whereType<Map>()
          .map((e) => _parseTrack(e.cast<String, dynamic>()))
          .whereType<ProviderTrack>()
          .toList();
    } catch (e) {
      if (kDebugMode)
        print('[MuseeServerProvider] getTrendingTracks error: $e');
      return const [];
    }
  }

  @override
  Future<List<ProviderAlbum>> getNewReleases({int limit = 20}) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/api/user/dashboard/made-for-you?page=0&limit=$limit',
      );
      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return const [];

      final data = json.decode(response.body);
      final items = _extractItems(data);
      return items
          .whereType<Map>()
          .map((e) => _parseAlbum(e.cast<String, dynamic>()))
          .whereType<ProviderAlbum>()
          .toList();
    } catch (e) {
      if (kDebugMode) print('[MuseeServerProvider] getNewReleases error: $e');
      return const [];
    }
  }

  // --- Parsing Helpers ---

  ProviderTrack? _parseTrack(Map<String, dynamic> json) {
    final trackId = json['track_id']?.toString();
    if (trackId == null) return null;

    final artistsList = (json['artists'] as List?) ?? const [];
    final artists = artistsList
        .whereType<Map>()
        .map((a) => _parseArtist(a.cast<String, dynamic>()))
        .whereType<ProviderArtist>()
        .toList();

    final album = json['album'] as Map<String, dynamic>?;

    return ProviderTrack(
      id: trackId,
      title: json['title']?.toString() ?? '',
      imageUrl:
          album?['cover_url']?.toString() ?? json['cover_url']?.toString(),
      source: MusicSource.musee,
      durationSeconds: (json['duration'] as num?)?.toInt(),
      isExplicit: json['is_explicit'] == true,
      artists: artists,
      albumId: album?['album_id']?.toString(),
      albumTitle: album?['title']?.toString(),
    );
  }

  ProviderAlbum? _parseAlbum(
    Map<String, dynamic> json, {
    bool includeTracks = false,
  }) {
    final albumId = json['album_id']?.toString();
    if (albumId == null) return null;

    final artistsList = (json['artists'] as List?) ?? const [];
    final artists = artistsList
        .whereType<Map>()
        .map((a) => _parseArtist(a.cast<String, dynamic>()))
        .whereType<ProviderArtist>()
        .toList();

    List<ProviderTrack>? tracks;
    if (includeTracks) {
      final tracksList = (json['tracks'] as List?) ?? const [];
      tracks = tracksList
          .whereType<Map>()
          .map((t) => _parseTrack(t.cast<String, dynamic>()))
          .whereType<ProviderTrack>()
          .toList();
    }

    return ProviderAlbum(
      id: albumId,
      title: json['title']?.toString() ?? '',
      coverUrl: json['cover_url']?.toString(),
      source: MusicSource.musee,
      year: json['release_date']?.toString()?.substring(0, 4),
      artists: artists,
      tracks: tracks,
    );
  }

  ProviderArtist? _parseArtist(Map<String, dynamic> json) {
    final artistId = json['artist_id']?.toString();
    if (artistId == null) return null;

    return ProviderArtist(
      id: artistId,
      name: json['name']?.toString() ?? 'Unknown Artist',
      avatarUrl: json['avatar_url']?.toString(),
      source: MusicSource.musee,
      bio: json['bio']?.toString(),
    );
  }

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
}
