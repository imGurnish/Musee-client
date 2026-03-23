import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/des_base.dart';
import 'package:pointycastle/block/modes/ecb.dart';

class JioSaavnSearchItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? language;

  const JioSaavnSearchItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.language,
  });
}

class JioSaavnArtistMeta {
  final String externalId;
  final String name;
  final String? imageUrl;

  const JioSaavnArtistMeta({
    required this.externalId,
    required this.name,
    this.imageUrl,
  });
}

class JioSaavnArtistDetail {
  final String id;
  final String name;
  final String? imageUrl;
  final String? bio;
  final String? language;
  final String? permaUrl;
  final Map<String, dynamic> rawPayload;

  const JioSaavnArtistDetail({
    required this.id,
    required this.name,
    this.imageUrl,
    this.bio,
    this.language,
    this.permaUrl,
    this.rawPayload = const {},
  });
}

class JioSaavnSongDetail {
  final String id;
  final String title;
  final String? albumId;
  final String? albumTitle;
  final String? imageUrl;
  final String? language;
  final String? releaseDate;
  final int duration;
  final String? permaUrl;
  final bool? hasLyrics;
  final bool? isDrm;
  final bool? isDolbyContent;
  final bool? has320kbps;
  final String? encryptedDrmMediaUrl;
  final String? encryptedMediaPath;
  final dynamic rights;
  final String? encryptedMediaUrl;
  final String? mediaPreviewUrl;
  final List<JioSaavnArtistMeta> artists;
  final Map<String, dynamic> rawPayload;

  const JioSaavnSongDetail({
    required this.id,
    required this.title,
    this.albumId,
    this.albumTitle,
    this.imageUrl,
    this.language,
    this.releaseDate,
    required this.duration,
    this.permaUrl,
    this.hasLyrics,
    this.isDrm,
    this.isDolbyContent,
    this.has320kbps,
    this.encryptedDrmMediaUrl,
    this.encryptedMediaPath,
    this.rights,
    this.encryptedMediaUrl,
    this.mediaPreviewUrl,
    this.artists = const [],
    this.rawPayload = const {},
  });
}

class JioSaavnAlbumDetail {
  final String id;
  final String title;
  final String? imageUrl;
  final String? language;
  final String? releaseDate;
  final String? permaUrl;
  final List<JioSaavnArtistMeta> artists;
  final List<JioSaavnSongDetail> songs;
  final Map<String, dynamic> rawPayload;

  const JioSaavnAlbumDetail({
    required this.id,
    required this.title,
    this.imageUrl,
    this.language,
    this.releaseDate,
    this.permaUrl,
    this.artists = const [],
    this.songs = const [],
    this.rawPayload = const {},
  });
}

class JioSaavnPlaylistDetail {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? language;
  final String? permaUrl;
  final List<JioSaavnSongDetail> songs;
  final Map<String, dynamic> rawPayload;

  const JioSaavnPlaylistDetail({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.language,
    this.permaUrl,
    this.songs = const [],
    this.rawPayload = const {},
  });
}

class JioSaavnApiClient {
  static const _timeout = Duration(seconds: 20);

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36',
    'Accept': 'application/json,text/plain,*/*',
    'Origin': AppSecrets.externalMusicOrigin,
    'Referer': AppSecrets.externalMusicReferer,
    'Cookie': 'L=english',
  };

  Uri _uri(Map<String, String> query) {
    return Uri.parse(AppSecrets.externalMusicBaseUrl).replace(queryParameters: {
      ...query,
      '_format': 'json',
      '_marker': '0',
      'ctx': 'web6dot0',
    });
  }

  Future<dynamic> _getJson(Map<String, String> query) async {
    final response = await http.get(_uri(query), headers: _headers).timeout(_timeout);
    if (response.statusCode != 200) {
      throw Exception('JioSaavn API error ${response.statusCode}');
    }
    dynamic data = json.decode(response.body);
    if (data is String) data = json.decode(data);
    return data;
  }

  Future<List<JioSaavnSearchItem>> searchTracks(String query) async {
    final data = await _getJson({
      '__call': 'search.getResults',
      'api_version': '4',
      'q': query,
      'p': '1',
      'n': '20',
    });
    final results = (data['results'] as List?) ?? const [];
    return results.whereType<Map>().map((entry) {
      final item = entry.cast<String, dynamic>();
      return JioSaavnSearchItem(
        id: item['id']?.toString() ?? '',
        title: _decodeHtml(item['title']?.toString() ?? ''),
        subtitle: _decodeHtml(item['subtitle']?.toString() ?? ''),
        imageUrl: _toLargeImage(item['image']?.toString()),
        language: item['language']?.toString(),
      );
    }).where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<JioSaavnSearchItem>> searchAlbums(String query) async {
    final data = await _getJson({
      '__call': 'search.getAlbumResults',
      'api_version': '4',
      'q': query,
      'p': '1',
      'n': '20',
    });
    final results = (data['results'] as List?) ?? const [];
    return results.whereType<Map>().map((entry) {
      final item = entry.cast<String, dynamic>();
      return JioSaavnSearchItem(
        id: item['id']?.toString() ?? '',
        title: _decodeHtml(item['title']?.toString() ?? ''),
        subtitle: _decodeHtml(item['subtitle']?.toString() ?? ''),
        imageUrl: _toLargeImage(item['image']?.toString()),
        language: item['language']?.toString(),
      );
    }).where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<JioSaavnSearchItem>> searchPlaylists(String query) async {
    final data = await _getJson({
      '__call': 'search.getPlaylistResults',
      'api_version': '4',
      'q': query,
      'p': '1',
      'n': '20',
    });
    final results = (data['results'] as List?) ?? const [];
    return results.whereType<Map>().map((entry) {
      final item = entry.cast<String, dynamic>();
      return JioSaavnSearchItem(
        id: item['id']?.toString() ?? '',
        title: _decodeHtml(item['title']?.toString() ?? ''),
        subtitle: _decodeHtml(item['subtitle']?.toString() ?? ''),
        imageUrl: _toLargeImage(item['image']?.toString()),
        language: item['more_info']?['language']?.toString(),
      );
    }).where((item) => item.id.isNotEmpty).toList();
  }

  Future<JioSaavnSongDetail> getSongDetails(String songId) async {
    final token = _normalizeToken(songId);

    try {
      final webapiData = await _getJson({
        '__call': 'webapi.get',
        'api_version': '4',
        'token': token,
        'type': 'song',
        'includeMetaTags': '0',
      });

      final song = _extractSongFromApiResponse(webapiData, token: token);
      if (song != null) return _songFromJson(song);
    } catch (_) {}

    try {
      final detailsData = await _getJson({
        '__call': 'song.getDetails',
        'pids': token,
      });

      final song = _extractSongFromApiResponse(detailsData, token: token);
      if (song != null) return _songFromJson(song);
    } catch (_) {}

    throw Exception('Unable to fetch song details for token: $token');
  }

  Future<JioSaavnAlbumDetail> getAlbumDetails(String albumId) async {
    final data = await _getJson({
      '__call': 'content.getAlbumDetails',
      'albumid': albumId,
    });

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid album details response');
    }

    final songs = ((data['songs'] as List?) ?? const [])
        .whereType<Map>()
        .map((song) => _songFromJson(song.cast<String, dynamic>()))
        .toList();

    final albumArtistMap = _extractArtistMapFromValue(data['artistMap']);
    final artists = albumArtistMap.entries
        .map((entry) => JioSaavnArtistMeta(externalId: entry.value, name: entry.key))
        .toList();

    String? language;
    if (songs.isNotEmpty) {
      language = songs.first.language;
    }

    return JioSaavnAlbumDetail(
      id: data['albumid']?.toString() ?? albumId,
      title: _decodeHtml(data['title']?.toString() ?? data['name']?.toString() ?? ''),
      imageUrl: _toLargeImage(data['image']?.toString()),
      language: language,
      releaseDate: data['release_date']?.toString(),
      permaUrl: data['perma_url']?.toString(),
      artists: artists,
      songs: songs,
      rawPayload: data,
    );
  }

  Future<JioSaavnPlaylistDetail> getPlaylistDetails(String playlistId) async {
    final data = await _getJson({
      '__call': 'playlist.getDetails',
      'listid': playlistId,
    });

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid playlist details response');
    }

    final songs = ((data['list'] as List?) ?? const [])
        .whereType<Map>()
        .map((song) => _songFromJson(song.cast<String, dynamic>()))
        .where((song) => song.id.isNotEmpty)
        .toList();

    return JioSaavnPlaylistDetail(
      id: data['listid']?.toString() ?? playlistId,
      title: _decodeHtml(data['title']?.toString() ?? ''),
      subtitle: _decodeHtml(data['subtitle']?.toString() ?? data['listname']?.toString() ?? ''),
      imageUrl: _toLargeImage(data['image']?.toString()),
      language: data['language']?.toString(),
      permaUrl: data['perma_url']?.toString(),
      songs: songs,
      rawPayload: data,
    );
  }

  Future<JioSaavnArtistDetail> getArtistDetails(String artistId) async {
    final token = _normalizeToken(artistId);

    final attempts = <Future<dynamic> Function()>[
      () => _getJson({
        '__call': 'webapi.get',
        'api_version': '4',
        'token': token,
        'type': 'artist',
      }),
      () => _getJson({
        '__call': 'artist.getArtistPageDetails',
        'artistId': token,
      }),
      () => _getJson({
        '__call': 'artist.getDetails',
        'artistid': token,
      }),
    ];

    for (final attempt in attempts) {
      try {
        final data = await attempt();
        final parsed = _extractArtistFromApiResponse(data, token: token);
        if (parsed != null) {
          return _artistFromJson(parsed, fallbackId: token);
        }
      } catch (_) {}
    }

    throw Exception('Unable to fetch artist details for token: $token');
  }

  Future<Uint8List?> downloadImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<(Uint8List bytes, String filename)> downloadSongAudio(JioSaavnSongDetail song) async {
    final url = _getPlayableUrl(song);
    if (url == null || url.isEmpty) {
      throw Exception('No playable URL found for song ${song.id}');
    }
    final response = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 2));
    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      throw Exception('Failed to download audio for ${song.title}');
    }
    return (response.bodyBytes, '${song.id}.mp3');
  }

  String? _getPlayableUrl(JioSaavnSongDetail song) {
    if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty) {
      final decrypted = _decryptMediaUrl(song.encryptedMediaUrl!);
      if (decrypted != null && decrypted.isNotEmpty) return decrypted;
    }
    return song.mediaPreviewUrl;
  }

  String? _decryptMediaUrl(String encryptedUrl) {
    try {
      final keyString = AppSecrets.externalMusicDecryptionKey;
      final key = Uint8List.fromList(utf8.encode(keyString));
      final params = KeyParameter(key);
      final blockCipher = ECBBlockCipher(_DESEngine());
      blockCipher.init(false, params);

      final encryptedBytes = base64.decode(encryptedUrl);
      final decryptedBytes = Uint8List(encryptedBytes.length);

      for (var i = 0; i < encryptedBytes.length; i += 8) {
        blockCipher.processBlock(encryptedBytes, i, decryptedBytes, i);
      }

      final padLength = decryptedBytes.last;
      if (padLength > 0 && padLength <= 8) {
        final unpadded = decryptedBytes.sublist(0, decryptedBytes.length - padLength);
        return utf8.decode(unpadded).trim();
      }
      return utf8.decode(decryptedBytes).trim();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('JioSaavn decrypt error: $e');
      }
      return null;
    }
  }

  JioSaavnSongDetail _songFromJson(Map<String, dynamic> json) {
    final artistMap = _extractArtistMapFromValue(json['artistMap']);
    final artists = artistMap.entries
        .map((entry) => JioSaavnArtistMeta(externalId: entry.value, name: entry.key))
        .toList();

    return JioSaavnSongDetail(
      id: json['id']?.toString() ?? '',
      title: _decodeHtml(json['song']?.toString() ?? json['title']?.toString() ?? ''),
      albumId: json['albumid']?.toString() ?? json['album_id']?.toString(),
      albumTitle: _decodeHtml(json['album']?.toString() ?? ''),
      imageUrl: _toLargeImage(json['image']?.toString()),
      language: json['language']?.toString(),
      releaseDate: json['release_date']?.toString(),
      duration: int.tryParse(json['duration']?.toString() ?? '0') ?? 0,
      permaUrl: json['perma_url']?.toString(),
      hasLyrics: _toBool(json['has_lyrics']),
      isDrm: _toBool(json['is_drm']),
      isDolbyContent: _toBool(json['is_dolby_content']),
      has320kbps: _toBool(json['320kbps'] ?? json['has_320kbps']),
      encryptedDrmMediaUrl: json['encrypted_drm_media_url']?.toString(),
      encryptedMediaPath: json['encrypted_media_path']?.toString(),
      rights: json['rights'],
      encryptedMediaUrl: json['encrypted_media_url']?.toString(),
      mediaPreviewUrl: json['media_preview_url']?.toString() ?? json['vlink']?.toString(),
      artists: artists,
      rawPayload: json,
    );
  }

  JioSaavnArtistDetail _artistFromJson(
    Map<String, dynamic> json, {
    required String fallbackId,
  }) {
    final id = json['id']?.toString() ??
        json['artistid']?.toString() ??
        fallbackId;
    final name = _decodeHtml(
      json['name']?.toString() ??
          json['title']?.toString() ??
          json['artist']?.toString() ??
          '',
    );
    final bio = _decodeHtml(
      json['bio']?.toString() ??
          json['description']?.toString() ??
          json['artistBio']?.toString() ??
          '',
    );

    return JioSaavnArtistDetail(
      id: id,
      name: name,
      imageUrl: _toLargeImage(json['image']?.toString()),
      bio: bio.isEmpty ? null : bio,
      language: json['language']?.toString(),
      permaUrl: json['perma_url']?.toString(),
      rawPayload: json,
    );
  }

  Map<String, String> _extractArtistMapFromValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value.map((key, val) => MapEntry(key.toString(), val.toString()));
    }
    return const {};
  }

  Map<String, dynamic>? _extractSongFromApiResponse(
    dynamic data, {
    required String token,
  }) {
    if (data is Map<String, dynamic>) {
      if (data.containsKey('songs') && data['songs'] is List) {
        final songs = data['songs'] as List;
        if (songs.isNotEmpty && songs.first is Map) {
          return (songs.first as Map).cast<String, dynamic>();
        }
      }

      if (data.containsKey(token) && data[token] is Map) {
        return (data[token] as Map).cast<String, dynamic>();
      }

      if (data['id'] != null || data['song'] != null || data['title'] != null) {
        return data;
      }

      for (final value in data.values) {
        if (value is Map) {
          final mapped = value.cast<String, dynamic>();
          if (mapped['id'] != null ||
              mapped['song'] != null ||
              mapped['title'] != null) {
            return mapped;
          }
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _extractArtistFromApiResponse(
    dynamic data, {
    required String token,
  }) {
    if (data is Map<String, dynamic>) {
      if (data['artist'] is Map) {
        return (data['artist'] as Map).cast<String, dynamic>();
      }

      if (data['artists'] is List) {
        final artists = data['artists'] as List;
        if (artists.isNotEmpty && artists.first is Map) {
          return (artists.first as Map).cast<String, dynamic>();
        }
      }

      if (data[token] is Map) {
        return (data[token] as Map).cast<String, dynamic>();
      }

      if (data['id'] != null || data['artistid'] != null || data['name'] != null) {
        return data;
      }

      for (final value in data.values) {
        if (value is Map) {
          final mapped = value.cast<String, dynamic>();
          if (mapped['id'] != null || mapped['artistid'] != null || mapped['name'] != null) {
            return mapped;
          }
        }
      }
    }
    return null;
  }

  bool? _toBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == '1' || normalized == 'true' || normalized == 'yes') return true;
    if (normalized == '0' || normalized == 'false' || normalized == 'no') return false;
    return null;
  }

  String _normalizeToken(String token) {
    var normalized = Uri.decodeComponent(token).trim();
    while (normalized.endsWith('_')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _decodeHtml(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .trim();
  }

  String? _toLargeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) return null;
    return imageUrl
        .replaceAll('-50x50.', '-500x500.')
        .replaceAll('-150x150.', '-500x500.');
  }
}

class _DESEngine extends DesBase implements BlockCipher {
  static const int _blockSize = 8;
  List<int>? _workingKey;

  @override
  String get algorithmName => 'DES';

  @override
  int get blockSize => _blockSize;

  @override
  void reset() {}

  @override
  void init(bool forEncryption, CipherParameters? params) {
    if (params is! KeyParameter) {
      throw ArgumentError(
        'Invalid parameter passed to DES init - ${params.runtimeType}',
      );
    }
    _workingKey = generateWorkingKey(forEncryption, params.key);
  }

  @override
  int processBlock(Uint8List inp, int inpOff, Uint8List out, int outOff) {
    if (_workingKey == null) {
      throw StateError('DES engine not initialised');
    }
    if (inpOff + _blockSize > inp.length) {
      throw ArgumentError('Input buffer too short');
    }
    if (outOff + _blockSize > out.length) {
      throw ArgumentError('Output buffer too short');
    }

    desFunc(_workingKey!, inp, inpOff, out, outOff);
    return _blockSize;
  }

  @override
  Uint8List process(Uint8List data) {
    final out = Uint8List(data.length);
    for (var offset = 0; offset < data.length; offset += _blockSize) {
      processBlock(data, offset, out, offset);
    }
    return out;
  }
}
