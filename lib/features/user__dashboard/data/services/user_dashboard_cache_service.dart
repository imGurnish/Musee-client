import 'package:hive/hive.dart';
import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class UserDashboardCacheService {
  Future<void> init();

  Future<DashboardRecommendationCache?> getRecommendations({
    required String artistName,
    required Duration ttl,
  });

  Future<void> cacheRecommendations({
    required String artistName,
    required String title,
    required List<DashboardItem> items,
  });

  Future<List<DashboardItem>?> getMadeForYou({
    required int page,
    required int limit,
    required Duration ttl,
  });

  Future<void> cacheMadeForYou({
    required int page,
    required int limit,
    required List<DashboardItem> items,
  });

  Future<List<DashboardItem>?> getTrending({
    required int page,
    required int limit,
    required Duration ttl,
  });

  Future<void> cacheTrending({
    required int page,
    required int limit,
    required List<DashboardItem> items,
  });

  Future<void> clearMadeForYou({int? page, int? limit});

  Future<void> clearTrending({int? page, int? limit});

  Future<void> clearRecommendations({String? artistName});
}

class DashboardRecommendationCache {
  final String title;
  final List<DashboardItem> items;

  const DashboardRecommendationCache({
    required this.title,
    required this.items,
  });
}

class UserDashboardCacheServiceImpl implements UserDashboardCacheService {
  static const String _boxName = 'user_dashboard_cache';

  final SupabaseClient _supabase;
  Box<dynamic>? _box;

  UserDashboardCacheServiceImpl(this._supabase);

  @override
  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
  }

  Box<dynamic> get _cacheBox {
    if (_box == null) {
      throw StateError(
        'UserDashboardCacheService not initialized. Call init() first.',
      );
    }
    return _box!;
  }

  String _cacheKey({required int page, required int limit}) {
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    return 'made_for_you:$userId:$page:$limit';
  }

  String _trendingCacheKey({required int page, required int limit}) {
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    return 'trending:$userId:$page:$limit';
  }

  String _recommendationsKey({required String artistName}) {
    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    final normalizedArtist = artistName.trim().toLowerCase();
    return 'recommendations:$userId:$normalizedArtist';
  }

  @override
  Future<DashboardRecommendationCache?> getRecommendations({
    required String artistName,
    required Duration ttl,
  }) async {
    final key = _recommendationsKey(artistName: artistName);
    final raw = _cacheBox.get(key);
    if (raw is! Map) return null;

    final payload = Map<String, dynamic>.from(raw);
    final cachedAtIso = payload['cached_at']?.toString();
    if (cachedAtIso == null || cachedAtIso.isEmpty) return null;

    final cachedAt = DateTime.tryParse(cachedAtIso);
    if (cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) >= ttl) return null;

    final title = payload['title']?.toString();
    final rawItems = payload['items'];
    if (title == null || title.isEmpty || rawItems is! List) return null;

    final items = rawItems
        .whereType<Map>()
        .map((entry) => _itemFromMap(Map<String, dynamic>.from(entry)))
        .toList();

    return DashboardRecommendationCache(title: title, items: items);
  }

  @override
  Future<void> cacheRecommendations({
    required String artistName,
    required String title,
    required List<DashboardItem> items,
  }) async {
    final key = _recommendationsKey(artistName: artistName);
    await _cacheBox.put(key, {
      'cached_at': DateTime.now().toIso8601String(),
      'title': title,
      'items': items.map(_itemToMap).toList(),
    });
  }

  @override
  Future<List<DashboardItem>?> getMadeForYou({
    required int page,
    required int limit,
    required Duration ttl,
  }) async {
    final key = _cacheKey(page: page, limit: limit);
    final raw = _cacheBox.get(key);
    if (raw is! Map) return null;

    final payload = Map<String, dynamic>.from(raw);
    final cachedAtIso = payload['cached_at']?.toString();
    if (cachedAtIso == null || cachedAtIso.isEmpty) return null;

    final cachedAt = DateTime.tryParse(cachedAtIso);
    if (cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) >= ttl) return null;

    final rawItems = payload['items'];
    if (rawItems is! List) return null;

    return rawItems
        .whereType<Map>()
        .map((entry) => _itemFromMap(Map<String, dynamic>.from(entry)))
        .toList();
  }

  @override
  Future<void> cacheMadeForYou({
    required int page,
    required int limit,
    required List<DashboardItem> items,
  }) async {
    final key = _cacheKey(page: page, limit: limit);
    await _cacheBox.put(key, {
      'cached_at': DateTime.now().toIso8601String(),
      'items': items.map(_itemToMap).toList(),
    });
  }

  @override
  Future<List<DashboardItem>?> getTrending({
    required int page,
    required int limit,
    required Duration ttl,
  }) async {
    final key = _trendingCacheKey(page: page, limit: limit);
    final raw = _cacheBox.get(key);
    if (raw is! Map) return null;

    final payload = Map<String, dynamic>.from(raw);
    final cachedAtIso = payload['cached_at']?.toString();
    if (cachedAtIso == null || cachedAtIso.isEmpty) return null;

    final cachedAt = DateTime.tryParse(cachedAtIso);
    if (cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) >= ttl) return null;

    final rawItems = payload['items'];
    if (rawItems is! List) return null;

    return rawItems
        .whereType<Map>()
        .map((entry) => _itemFromMap(Map<String, dynamic>.from(entry)))
        .toList();
  }

  @override
  Future<void> cacheTrending({
    required int page,
    required int limit,
    required List<DashboardItem> items,
  }) async {
    final key = _trendingCacheKey(page: page, limit: limit);
    await _cacheBox.put(key, {
      'cached_at': DateTime.now().toIso8601String(),
      'items': items.map(_itemToMap).toList(),
    });
  }

  @override
  Future<void> clearMadeForYou({int? page, int? limit}) async {
    if (page != null && limit != null) {
      await _cacheBox.delete(_cacheKey(page: page, limit: limit));
      return;
    }

    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    final prefix = 'made_for_you:$userId:';
    final keys = _cacheBox.keys.where((k) => k.toString().startsWith(prefix));
    await _cacheBox.deleteAll(keys);
  }

  @override
  Future<void> clearTrending({int? page, int? limit}) async {
    if (page != null && limit != null) {
      await _cacheBox.delete(_trendingCacheKey(page: page, limit: limit));
      return;
    }

    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    final prefix = 'trending:$userId:';
    final keys = _cacheBox.keys.where((k) => k.toString().startsWith(prefix));
    await _cacheBox.deleteAll(keys);
  }

  @override
  Future<void> clearRecommendations({String? artistName}) async {
    if (artistName != null && artistName.trim().isNotEmpty) {
      await _cacheBox.delete(_recommendationsKey(artistName: artistName));
      return;
    }

    final userId = _supabase.auth.currentUser?.id ?? 'anonymous';
    final prefix = 'recommendations:$userId:';
    final keys = _cacheBox.keys.where((k) => k.toString().startsWith(prefix));
    await _cacheBox.deleteAll(keys);
  }

  Map<String, dynamic> _itemToMap(DashboardItem item) {
    return {
      'id': item.id,
      'title': item.title,
      'cover_url': item.coverUrl,
      'duration': item.duration,
      'type': item.type.name,
      'track_id': item.trackId,
      'album_id': item.albumId,
      'is_cached': item.isCached,
      'local_image_path': item.localImagePath,
      'artists': item.artists
          .map(
            (artist) => {
              'artist_id': artist.artistId,
              'name': artist.name,
              'avatar_url': artist.avatarUrl,
            },
          )
          .toList(),
    };
  }

  DashboardItem _itemFromMap(Map<String, dynamic> map) {
    final rawType = map['type']?.toString() ?? 'album';
    final itemType = switch (rawType) {
      'track' => DashboardItemType.track,
      'playlist' => DashboardItemType.playlist,
      _ => DashboardItemType.album,
    };

    final rawArtists = map['artists'];
    final artists = rawArtists is List
        ? rawArtists
              .whereType<Map>()
              .map(
                (entry) => DashboardArtist(
                  artistId: entry['artist_id']?.toString() ?? '',
                  name: entry['name']?.toString() ?? 'Artist',
                  avatarUrl: entry['avatar_url']?.toString(),
                ),
              )
              .toList()
        : const <DashboardArtist>[];

    return DashboardItem(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      coverUrl: map['cover_url']?.toString(),
      duration: (map['duration'] is num)
          ? (map['duration'] as num).toInt()
          : int.tryParse(map['duration']?.toString() ?? ''),
      artists: artists,
      type: itemType,
      trackId: map['track_id']?.toString(),
      albumId: map['album_id']?.toString(),
      isCached: map['is_cached'] == true,
      localImagePath: map['local_image_path']?.toString(),
    );
  }
}
