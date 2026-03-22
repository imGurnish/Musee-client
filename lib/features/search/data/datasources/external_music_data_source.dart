import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/block/des_base.dart';

/// External Music API data source for searching songs, albums, and artists.
/// Calls the external PHP API directly without requiring yt-dlp.
class ExternalMusicDataSource {
  static const _timeout = Duration(seconds: 15);

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0 Safari/537.36',
    'Accept': 'application/json,text/plain,*/*',
    'Origin': AppSecrets.externalMusicOrigin,
    'Referer': AppSecrets.externalMusicReferer,
    'Cookie': 'L=english',
  };

  /// Search for songs, albums, and artists.
  /// Returns a map with 'songs', 'albums', 'artists' lists.
  Future<ExternalMusicSearchResult> search(String query) async {
    try {
      final uri = Uri.parse(AppSecrets.externalMusicBaseUrl).replace(
        queryParameters: {
          '__call': 'autocomplete.get',
          'ctx': 'web6dot0',
          'query': query,
          '_format': 'json',
          '_marker': '0',
        },
      );

      if (kDebugMode) {
        print('[ExternalAPI] Search request: $uri');
      }

      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (kDebugMode) {
        print('[ExternalAPI] Search status: ${response.statusCode}');
        print('[ExternalAPI] Search body length: ${response.body.length}');
      }

      if (response.statusCode != 200) {
        if (kDebugMode) {
          print(
            '[ExternalAPI] Search failed: ${response.statusCode} - ${response.body.substring(0, (response.body.length > 200) ? 200 : response.body.length)}',
          );
        }
        return const ExternalMusicSearchResult();
      }

      dynamic data = json.decode(response.body);
      // API sometimes returns stringified JSON
      if (data is String) {
        data = json.decode(data);
      }

      if (data is! Map<String, dynamic>) {
        if (kDebugMode) {
          print(
            '[ExternalAPI] Search unexpected data type: ${data.runtimeType}',
          );
        }
        return const ExternalMusicSearchResult();
      }

      final result = ExternalMusicSearchResult.fromJson(data);
      if (kDebugMode) {
        print(
          '[ExternalAPI] Search results: ${result.songs.length} songs, ${result.albums.length} albums, ${result.artists.length} artists',
        );
      }
      return result;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('[ExternalAPI] Search error: $e');
        print('[ExternalAPI] Stack trace: $stackTrace');
      }
      return const ExternalMusicSearchResult();
    }
  }

  /// Get song details by ID (token) to retrieve the media URL.
  Future<ExternalMusicSongDetail?> getSongById(String songId) async {
    // 1. Try webapi.get first
    try {
      final uri = Uri.parse(AppSecrets.externalMusicBaseUrl).replace(
        queryParameters: {
          '__call': 'webapi.get',
          'type': 'song',
          'token': _normalizeToken(songId),
          '_format': 'json',
          '_marker': '0',
        },
      );

      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        dynamic data = json.decode(response.body);
        if (data is String) data = json.decode(data);

        // Check if data is valid map and not empty list
        if (data is Map<String, dynamic> && data.isNotEmpty) {
          final songData = data.values.first;
          if (songData is Map<String, dynamic>) {
            return ExternalMusicSongDetail.fromJson(songData);
          }
        }
      }

      if (kDebugMode) {
        print('External webapi.get failed for $songId, trying fallback...');
      }
    } catch (e) {
      if (kDebugMode) print('External webapi.get error: $e');
    }

    // 2. Fallback: Try song.getDetails via pids
    try {
      final uri = Uri.parse(AppSecrets.externalMusicBaseUrl).replace(
        queryParameters: {
          '__call': 'song.getDetails',
          'pids': _normalizeToken(songId),
          '_format': 'json',
          '_marker': '0',
        },
      );

      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return null;

      dynamic data = json.decode(response.body);
      if (data is String) data = json.decode(data);

      if (data is Map<String, dynamic>) {
        // song.getDetails often returns { "songs": [ ... ] } or Keyed JSON
        if (data.containsKey('songs') &&
            data['songs'] is List &&
            (data['songs'] as List).isNotEmpty) {
          return ExternalMusicSongDetail.fromJson(data['songs'][0]);
        }

        if (data.isNotEmpty) {
          final songData = data.values.first;
          if (songData is Map<String, dynamic>) {
            return ExternalMusicSongDetail.fromJson(songData);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('External song.getDetails error: $e');
    }

    return null;
  }

  /// Get album details by ID.
  Future<ExternalMusicAlbumDetail?> getAlbumDetails(String albumId) async {
    try {
      final uri = Uri.parse(AppSecrets.externalMusicBaseUrl).replace(
        queryParameters: {
          '__call': 'content.getAlbumDetails',
          'albumid': _normalizeToken(albumId),
          '_format': 'json',
          '_marker': '0',
          'ctx': 'web6dot0',
        },
      );

      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode != 200) return null;

      dynamic data = json.decode(response.body);
      if (data is String) data = json.decode(data);

      if (data is Map<String, dynamic>) {
        return ExternalMusicAlbumDetail.fromJson(data);
      }
    } catch (e) {
      if (kDebugMode) print('External getAlbumDetails error: $e');
    }
    return null;
  }

  /// Get the best available playable URL from song details.
  /// Tries the decrypted URL first, then falls back to preview URL.
  String? getPlayableUrl(ExternalMusicSongDetail song) {
    if (song.encryptedMediaUrl != null) {
      final decrypted = decryptMediaUrl(song.encryptedMediaUrl!);
      if (decrypted != null && decrypted.isNotEmpty) {
        return decrypted;
      }
    }
    // Fallback to preview URL (which might be 404, but it's a backup)
    return song.mediaPreviewUrl;
  }

  /// Decrypt the encrypted media URL to get a playable stream URL.
  /// Uses DES-ECB decryption with known key.
  String? decryptMediaUrl(String encryptedUrl) {
    try {
      final keyString = AppSecrets.externalMusicDecryptionKey;
      final key = Uint8List.fromList(utf8.encode(keyString));
      final params = KeyParameter(key);
      final blockCipher = ECBBlockCipher(DESEngine());
      blockCipher.init(false, params); // false for decryption

      final encryptedBytes = base64.decode(encryptedUrl);
      final decryptedBytes = Uint8List(encryptedBytes.length);

      for (var i = 0; i < encryptedBytes.length; i += 8) {
        blockCipher.processBlock(encryptedBytes, i, decryptedBytes, i);
      }

      // Try PKCS7 unpadding
      try {
        final padLength = decryptedBytes.last;
        if (padLength > 0 && padLength <= 8) {
          final unpadded = decryptedBytes.sublist(
            0,
            decryptedBytes.length - padLength,
          );
          return utf8.decode(unpadded);
        }
      } catch (_) {
        // If unpadding fails, try straight decode and trim
      }

      return utf8.decode(decryptedBytes).trim();
    } catch (e) {
      if (kDebugMode) print('External decrypt error: $e');
      return null;
    }
  }

  /// Get song suggestions/recommendations based on a song ID.
  /// Uses multiple strategies:
  /// 1. Fetch song details to get real pid, then reco.getreco
  /// 2. Station-based suggestions via webapi.getSuggestedSongs
  /// 3. Fall back to title-based search
  Future<List<ExternalMusicSongDetail>> getSongSuggestions(
    String songId, {
    int limit = 10,
  }) async {
    final normalizedId = _normalizeToken(songId);

    // Strategy 1: webapi.getSuggestedSongs with the song token
    try {
      if (kDebugMode) {
        print('[ExternalAPI] Trying webapi.getSuggestedSongs with token=$normalizedId');
      }

      final suggested = await _fetchSuggestedSongs(normalizedId, limit);
      if (suggested.isNotEmpty) return suggested;

      // We need song details for strategies 2 and 3
      final songDetail = await getSongById(normalizedId);
      final pid = songDetail?.id ?? normalizedId;

      // Strategy 2: Station-based suggestions
      if (kDebugMode) {
        print('[ExternalAPI] getSuggestedSongs empty, trying station suggestions');
      }
      final stationResults = await _fetchStationSuggestions(pid, limit);
      if (stationResults.isNotEmpty) return stationResults;

      // Strategy 3: Search by song title + artist for similar tracks
      if (songDetail != null) {
        final searchQuery = songDetail.title;
        if (kDebugMode) {
          print(
            '[ExternalAPI] Station empty, searching by title: "$searchQuery"',
          );
        }
        final searchResults = await _fetchSearchSuggestions(
          searchQuery,
          excludeId: pid,
          limit: limit,
        );
        if (searchResults.isNotEmpty) return searchResults;
      }
    } catch (e) {
      if (kDebugMode) {
        print('[ExternalAPI] Song suggestions error: $e');
      }
    }

    return const [];
  }

  /// Strategy 1: webapi.getSuggestedSongs (Works with string slugs)
  Future<List<ExternalMusicSongDetail>> _fetchSuggestedSongs(
    String token,
    int limit,
  ) async {
    try {
      if (kDebugMode) {
        print('[ExternalAPI] Trying webapi.getSuggestedSongs with $token');
      }
      final uri = Uri.parse(AppSecrets.externalMusicBaseUrl).replace(
        queryParameters: {
          '__call': 'webapi.getSuggestedSongs',
          'video_id': token, // The endpoint uses video_id or id for the token
          '_format': 'json',
          '_marker': '0',
          'ctx': 'web6dot0',
          'limit': limit.toString(),
        },
      );

      final response = await http.get(uri, headers: _headers).timeout(_timeout);

      if (response.statusCode == 200) {
        dynamic data = json.decode(response.body);
        if (data is String) data = json.decode(data);

        // webapi.getSuggestedSongs usually returns { "Xo1Z1OwW": { ...song details... } }
        // or a similar map structure containing recommended songs.
        if (data is Map<String, dynamic> && data.containsKey(token)) {
          final related = data[token]?['related_songs'];
          if (related != null) {
            return _parseSongList(related, limit);
          }
        }
        
        // Also try standard parsing just in case
        final results = _parseSongList(data, limit);
        if (results.isNotEmpty) return results;
      }
    } catch (e) {
      if (kDebugMode) print('[ExternalAPI] getSuggestedSongs error: $e');
    }
    return const [];
  }

  /// Strategy 2: webapi.getSuggestedSongs via station
  Future<List<ExternalMusicSongDetail>> _fetchStationSuggestions(
    String songId,
    int limit,
  ) async {
    try {
      // Create a radio station from the song
      final stationUri = Uri.parse(AppSecrets.externalMusicBaseUrl).replace(
        queryParameters: {
          '__call': 'webradio.createEntityStation',
          'entity_id': json.encode([songId]),
          'entity_type': 'queue',
          '_format': 'json',
          '_marker': '0',
          'ctx': 'web6dot0',
        },
      );

      final stationResponse =
          await http.get(stationUri, headers: _headers).timeout(_timeout);

      if (stationResponse.statusCode != 200) return const [];

      dynamic stationData = json.decode(stationResponse.body);
      if (stationData is String) stationData = json.decode(stationData);

      // Extract station ID
      String? stationId;
      if (stationData is Map<String, dynamic>) {
        stationId = stationData['stationid']?.toString();
      }

      if (stationId == null || stationId.isEmpty) return const [];

      // Get songs from the station
      final songsUri = Uri.parse(AppSecrets.externalMusicBaseUrl).replace(
        queryParameters: {
          '__call': 'webradio.getSong',
          'stationid': stationId,
          'k': limit.toString(),
          '_format': 'json',
          '_marker': '0',
          'ctx': 'web6dot0',
        },
      );

      final songsResponse =
          await http.get(songsUri, headers: _headers).timeout(_timeout);

      if (songsResponse.statusCode != 200) return const [];

      dynamic songsData = json.decode(songsResponse.body);
      if (songsData is String) songsData = json.decode(songsData);

      if (kDebugMode) {
        print(
          '[ExternalAPI] Station songs response type: ${songsData.runtimeType}',
        );
      }

      return _parseSongList(songsData, limit);
    } catch (e) {
      if (kDebugMode) print('[ExternalAPI] Station suggestions error: $e');
      return const [];
    }
  }

  /// Strategy 3: Search by title to find similar tracks
  Future<List<ExternalMusicSongDetail>> _fetchSearchSuggestions(
    String query, {
    required String excludeId,
    required int limit,
  }) async {
    try {
      final searchResult = await search(query);
      // Convert search songs to song details, filtering out the original
      final filtered = searchResult.songs
          .where((s) => s.id != excludeId)
          .take(limit)
          .toList();

      // Fetch full details for each song
      final details = <ExternalMusicSongDetail>[];
      for (final song in filtered) {
        final detail = await getSongById(song.id);
        if (detail != null) {
          details.add(detail);
        }
        if (details.length >= limit) break;
      }

      if (kDebugMode) {
        print('[ExternalAPI] Search suggestions: ${details.length} results');
      }
      return details;
    } catch (e) {
      if (kDebugMode) print('[ExternalAPI] Search suggestions error: $e');
      return const [];
    }
  }

  /// Parse a song list from various API response formats
  List<ExternalMusicSongDetail> _parseSongList(dynamic data, int limit) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (e) =>
                ExternalMusicSongDetail.fromJson(e.cast<String, dynamic>()),
          )
          .take(limit)
          .toList();
    }

    if (data is Map<String, dynamic>) {
      return data.values
          .whereType<Map>()
          .map(
            (e) =>
                ExternalMusicSongDetail.fromJson(e.cast<String, dynamic>()),
          )
          .take(limit)
          .toList();
    }

    return const [];
  }

  /// Normalize token by removing trailing underscores.
  String _normalizeToken(String token) {
    var result = Uri.decodeComponent(token).trim();
    while (result.endsWith('_')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}

/// Search results from External API.
class ExternalMusicSearchResult {
  final List<ExternalMusicSong> songs;
  final List<ExternalMusicAlbum> albums;
  final List<ExternalMusicArtist> artists;

  const ExternalMusicSearchResult({
    this.songs = const [],
    this.albums = const [],
    this.artists = const [],
  });

  bool get isEmpty => songs.isEmpty && albums.isEmpty && artists.isEmpty;

  factory ExternalMusicSearchResult.fromJson(Map<String, dynamic> json) {
    final songsData = json['songs']?['data'] as List? ?? [];
    final albumsData = json['albums']?['data'] as List? ?? [];
    final artistsData = json['artists']?['data'] as List? ?? [];
    // Also check topquery for artist
    final topQueryData = json['topquery']?['data'] as List? ?? [];

    return ExternalMusicSearchResult(
      songs: songsData
          .whereType<Map>()
          .map((e) => ExternalMusicSong.fromJson(e.cast<String, dynamic>()))
          .toList(),
      albums: albumsData
          .whereType<Map>()
          .map((e) => ExternalMusicAlbum.fromJson(e.cast<String, dynamic>()))
          .toList(),
      artists: [
        ...artistsData.whereType<Map>().map(
          (e) => ExternalMusicArtist.fromJson(e.cast<String, dynamic>()),
        ),
        ...topQueryData
            .whereType<Map>()
            .where((e) => e['type'] == 'artist')
            .map(
              (e) => ExternalMusicArtist.fromJson(e.cast<String, dynamic>()),
            ),
      ],
    );
  }
}

/// Song from External search results.
class ExternalMusicSong {
  final String id;
  final String title;
  final String? imageUrl;
  final String? album;
  final String? primaryArtists;
  final String? url;
  final String? language;
  final int? duration;

  const ExternalMusicSong({
    required this.id,
    required this.title,
    this.imageUrl,
    this.album,
    this.primaryArtists,
    this.url,
    this.language,
    this.duration,
  });

  factory ExternalMusicSong.fromJson(Map<String, dynamic> json) {
    // Get higher resolution image
    String? imageUrl = json['image'] as String?;
    if (imageUrl != null) {
      imageUrl = imageUrl
          .replaceAll('-50x50.', '-500x500.')
          .replaceAll('-150x150.', '-500x500.');
    }

    return ExternalMusicSong(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['song']?.toString() ?? '',
      imageUrl: imageUrl,
      album: json['album'] as String?,
      primaryArtists:
          json['more_info']?['primary_artists'] as String? ??
          json['primary_artists'] as String?,
      url: json['url'] as String?,
      language:
          json['more_info']?['language'] as String? ??
          json['language'] as String?,
      duration: _parseDuration(
        json['duration'] ?? json['more_info']?['duration'],
      ),
    );
  }

  static int? _parseDuration(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Album from External search results.
class ExternalMusicAlbum {
  final String id;
  final String title;
  final String? imageUrl;
  final String? music;
  final String? url;
  final String? year;
  final String? language;

  const ExternalMusicAlbum({
    required this.id,
    required this.title,
    this.imageUrl,
    this.music,
    this.url,
    this.year,
    this.language,
  });

  factory ExternalMusicAlbum.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['image'] as String?;
    if (imageUrl != null) {
      imageUrl = imageUrl
          .replaceAll('-50x50.', '-500x500.')
          .replaceAll('-150x150.', '-500x500.');
    }

    return ExternalMusicAlbum(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: imageUrl,
      music: json['music'] as String?,
      url: json['url'] as String?,
      year: json['more_info']?['year'] as String? ?? json['year'] as String?,
      language:
          json['more_info']?['language'] as String? ??
          json['language'] as String?,
    );
  }
}

/// Artist from External search results.
class ExternalMusicArtist {
  final String id;
  final String name;
  final String? imageUrl;
  final String? url;
  final String? role;

  const ExternalMusicArtist({
    required this.id,
    required this.name,
    this.imageUrl,
    this.url,
    this.role,
  });

  factory ExternalMusicArtist.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['image'] as String?;
    if (imageUrl != null && !imageUrl.contains('artist-default')) {
      imageUrl = imageUrl
          .replaceAll('-50x50.', '-500x500.')
          .replaceAll('-150x150.', '-500x500.');
    }

    return ExternalMusicArtist(
      id: json['id']?.toString() ?? '',
      name: json['title']?.toString() ?? json['name']?.toString() ?? '',
      imageUrl: imageUrl,
      url: json['url'] as String?,
      role: json['extra'] as String? ?? json['description'] as String?,
    );
  }
}

/// Detailed song info from External API.
class ExternalMusicSongDetail {
  final String id;
  final String title;
  final String? imageUrl;
  final String? album;
  final String? primaryArtists;
  final String? encryptedMediaUrl;
  final String? mediaPreviewUrl;
  final int? duration;
  final bool is320kbps;

  const ExternalMusicSongDetail({
    required this.id,
    required this.title,
    this.imageUrl,
    this.album,
    this.primaryArtists,
    this.encryptedMediaUrl,
    this.mediaPreviewUrl,
    this.duration,
    this.is320kbps = false,
  });

  factory ExternalMusicSongDetail.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['image'] as String?;
    if (imageUrl != null) {
      imageUrl = imageUrl
          .replaceAll('-50x50.', '-500x500.')
          .replaceAll('-150x150.', '-500x500.');
    }

    return ExternalMusicSongDetail(
      id: json['id']?.toString() ?? '',
      title: json['song']?.toString() ?? json['title']?.toString() ?? '',
      imageUrl: imageUrl,
      album: json['album'] as String?,
      primaryArtists: json['primary_artists'] as String?,
      encryptedMediaUrl: json['encrypted_media_url'] as String?,
      mediaPreviewUrl: json['media_preview_url'] as String?,
      duration: ExternalMusicSong._parseDuration(json['duration']),
      is320kbps: json['320kbps'] == 'true' || json['320kbps'] == true,
    );
  }
}

/// Detailed album info from External API.
class ExternalMusicAlbumDetail {
  final String id;
  final String title;
  final String? imageUrl;
  final String? primaryArtists;
  final String? year;
  final List<ExternalMusicSongDetail> songs;

  const ExternalMusicAlbumDetail({
    required this.id,
    required this.title,
    this.imageUrl,
    this.primaryArtists,
    this.year,
    this.songs = const [],
  });

  factory ExternalMusicAlbumDetail.fromJson(Map<String, dynamic> json) {
    String? imageUrl = json['image'] as String?;
    if (imageUrl != null) {
      imageUrl = imageUrl
          .replaceAll('-50x50.', '-500x500.')
          .replaceAll('-150x150.', '-500x500.');
    }

    final songsList = json['songs'] as List? ?? [];

    return ExternalMusicAlbumDetail(
      id: json['albumid']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      imageUrl: imageUrl,
      primaryArtists: json['primary_artists'] as String?,
      year: json['year'] as String?,
      songs: songsList
          .whereType<Map>()
          .map(
            (e) => ExternalMusicSongDetail.fromJson(e.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

/// DES Engine implementation since it's missing in PointyCastle 4.0.0
class DESEngine extends DesBase implements BlockCipher {
  static const int _blockSize = 8;
  List<int>? _workingKey;

  @override
  String get algorithmName => 'DES';

  @override
  int get blockSize => _blockSize;

  @override
  void init(bool forEncryption, CipherParameters? params) {
    if (params is KeyParameter) {
      _workingKey = generateWorkingKey(forEncryption, params.key);
    }
  }

  @override
  int processBlock(Uint8List inp, int inpOff, Uint8List out, int outOff) {
    if (_workingKey == null) {
      throw StateError('DES engine not initialised');
    }
    desFunc(_workingKey!, inp, inpOff, out, outOff);
    return blockSize;
  }

  @override
  Uint8List process(Uint8List data) {
    final out = Uint8List(blockSize);
    processBlock(data, 0, out, 0);
    return out;
  }

  @override
  void reset() {}
}
