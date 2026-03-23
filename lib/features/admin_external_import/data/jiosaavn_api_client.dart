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

class JioSaavnSongDetail {
  final String id;
  final String title;
  final String? albumId;
  final String? albumTitle;
  final String? imageUrl;
  final String? language;
  final String? releaseDate;
  final int duration;
  final String? encryptedMediaUrl;
  final String? mediaPreviewUrl;
  final List<JioSaavnArtistMeta> artists;

  const JioSaavnSongDetail({
    required this.id,
    required this.title,
    this.albumId,
    this.albumTitle,
    this.imageUrl,
    this.language,
    this.releaseDate,
    required this.duration,
    this.encryptedMediaUrl,
    this.mediaPreviewUrl,
    this.artists = const [],
  });
}

class JioSaavnAlbumDetail {
  final String id;
  final String title;
  final String? imageUrl;
  final String? language;
  final String? releaseDate;
  final List<JioSaavnArtistMeta> artists;
  final List<JioSaavnSongDetail> songs;

  const JioSaavnAlbumDetail({
    required this.id,
    required this.title,
    this.imageUrl,
    this.language,
    this.releaseDate,
    this.artists = const [],
    this.songs = const [],
  });
}

class JioSaavnPlaylistDetail {
  final String id;
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final String? language;
  final List<JioSaavnSongDetail> songs;

  const JioSaavnPlaylistDetail({
    required this.id,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.language,
    this.songs = const [],
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
      artists: artists,
      songs: songs,
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
      songs: songs,
    );
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
      encryptedMediaUrl: json['encrypted_media_url']?.toString(),
      mediaPreviewUrl: json['media_preview_url']?.toString() ?? json['vlink']?.toString(),
      artists: artists,
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
