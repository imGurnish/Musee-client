import 'package:hive/hive.dart';
import 'package:musee/core/cache/cache_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class UserMediaDetailCacheService {
  Future<void> init();

  Future<Map<String, dynamic>?> getAlbum(String albumId);
  Future<void> cacheAlbum(String albumId, Map<String, dynamic> payload);

  Future<Map<String, dynamic>?> getPlaylist(String playlistId);
  Future<void> cachePlaylist(String playlistId, Map<String, dynamic> payload);

  Future<List<Map<String, dynamic>>> getAllAlbums();
  Future<List<Map<String, dynamic>>> getAllPlaylists();
}

class UserMediaDetailCacheServiceImpl implements UserMediaDetailCacheService {
  final SupabaseClient _supabase;
  Box<dynamic>? _box;

  UserMediaDetailCacheServiceImpl(this._supabase);

  @override
  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(CacheConfig.mediaDetailBoxName);
  }

  Box<dynamic> get _cacheBox {
    if (_box == null) {
      throw StateError(
        'UserMediaDetailCacheService not initialized. Call init() first.',
      );
    }
    return _box!;
  }

  String _albumKey(String albumId) {
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    return 'album:$userId:$albumId';
  }

  String _playlistKey(String playlistId) {
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    return 'playlist:$userId:$playlistId';
  }

  String _albumPrefix() {
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    return 'album:$userId:';
  }

  String _playlistPrefix() {
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    return 'playlist:$userId:';
  }

  @override
  Future<Map<String, dynamic>?> getAlbum(String albumId) async {
    final raw = _cacheBox.get(_albumKey(albumId));
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  @override
  Future<void> cacheAlbum(String albumId, Map<String, dynamic> payload) async {
    await _cacheBox.put(_albumKey(albumId), {
      ...payload,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> getPlaylist(String playlistId) async {
    final raw = _cacheBox.get(_playlistKey(playlistId));
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }

  @override
  Future<void> cachePlaylist(
    String playlistId,
    Map<String, dynamic> payload,
  ) async {
    await _cacheBox.put(_playlistKey(playlistId), {
      ...payload,
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAllAlbums() async {
    final prefix = _albumPrefix();
    return _cacheBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .map((key) => _cacheBox.get(key))
        .whereType<Map>()
      .map((payload) => Map<String, dynamic>.from(payload))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllPlaylists() async {
    final prefix = _playlistPrefix();
    return _cacheBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .map((key) => _cacheBox.get(key))
        .whereType<Map>()
        .map((payload) => Map<String, dynamic>.from(payload))
        .toList();
  }
}
