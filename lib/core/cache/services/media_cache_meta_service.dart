import 'package:hive/hive.dart';
import 'package:musee/core/cache/cache_config.dart';
import 'package:musee/core/cache/cache_policy.dart';
import 'package:musee/core/cache/models/cache_entity_type.dart';
import 'package:musee/core/cache/models/cache_record_meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class MediaCacheMetaService {
  Future<void> init();

  String buildRecordKey({
    required CacheEntityType entityType,
    required String entityId,
    String source = 'musee',
  });

  Future<CacheRecordMeta?> getMeta(String recordKey);

  Future<void> upsertMeta({
    required String recordKey,
    required CacheEntityType entityType,
    DateTime? fetchedAt,
    DateTime? serverUpdatedAt,
  });

  Future<void> markAccessed(String recordKey, {DateTime? accessedAt});

  Future<void> markSyncPending(String recordKey);

  Future<void> markSyncFailed(String recordKey, {String? error});

  Future<void> markSynced(String recordKey, {DateTime? syncedAt});

  Future<bool> isExpired(String recordKey, {DateTime? now});

  Future<bool> isStale(String recordKey, {DateTime? now});

  Future<void> invalidate(String recordKey);
}

class MediaCacheMetaServiceImpl implements MediaCacheMetaService {
  final SupabaseClient _supabase;
  Box<dynamic>? _box;

  MediaCacheMetaServiceImpl(this._supabase);

  @override
  Future<void> init() async {
    _box ??= await Hive.openBox<dynamic>(CacheConfig.mediaMetaBoxName);
  }

  Box<dynamic> get _metaBox {
    if (_box == null) {
      throw StateError('MediaCacheMetaService not initialized. Call init() first.');
    }
    return _box!;
  }

  String get _userId => _supabase.auth.currentUser?.id ?? 'anonymous';

  @override
  String buildRecordKey({
    required CacheEntityType entityType,
    required String entityId,
    String source = 'musee',
  }) {
    return '$_userId:$source:${entityType.name}:$entityId';
  }

  @override
  Future<CacheRecordMeta?> getMeta(String recordKey) async {
    final raw = _metaBox.get(recordKey);
    if (raw is! Map) return null;
    return CacheRecordMeta.fromMap(Map<String, dynamic>.from(raw));
  }

  @override
  Future<void> upsertMeta({
    required String recordKey,
    required CacheEntityType entityType,
    DateTime? fetchedAt,
    DateTime? serverUpdatedAt,
  }) async {
    final now = fetchedAt ?? DateTime.now();
    final existing = await getMeta(recordKey);

    final meta = CacheRecordMeta(
      recordKey: recordKey,
      entityType: entityType,
      fetchedAt: now,
      expiresAt: CachePolicy.computeExpiry(entityType, now),
      serverUpdatedAt: serverUpdatedAt ?? existing?.serverUpdatedAt,
      lastAccessedAt: existing?.lastAccessedAt,
      lastSyncedAt: existing?.lastSyncedAt,
      syncState: existing?.syncState ?? CacheSyncState.synced,
      retryCount: existing?.retryCount ?? 0,
      lastError: existing?.lastError,
    );

    await _metaBox.put(recordKey, meta.toMap());
  }

  @override
  Future<void> markAccessed(String recordKey, {DateTime? accessedAt}) async {
    final existing = await getMeta(recordKey);
    if (existing == null) return;
    final updated = existing.copyWith(lastAccessedAt: accessedAt ?? DateTime.now());
    await _metaBox.put(recordKey, updated.toMap());
  }

  @override
  Future<void> markSyncPending(String recordKey) async {
    final existing = await getMeta(recordKey);
    if (existing == null) return;
    final updated = existing.copyWith(
      syncState: CacheSyncState.pending,
      retryCount: existing.retryCount,
      lastError: null,
    );
    await _metaBox.put(recordKey, updated.toMap());
  }

  @override
  Future<void> markSyncFailed(String recordKey, {String? error}) async {
    final existing = await getMeta(recordKey);
    if (existing == null) return;
    final updated = existing.copyWith(
      syncState: CacheSyncState.failed,
      retryCount: existing.retryCount + 1,
      lastError: error,
    );
    await _metaBox.put(recordKey, updated.toMap());
  }

  @override
  Future<void> markSynced(String recordKey, {DateTime? syncedAt}) async {
    final existing = await getMeta(recordKey);
    if (existing == null) return;
    final updated = existing.copyWith(
      syncState: CacheSyncState.synced,
      lastSyncedAt: syncedAt ?? DateTime.now(),
      retryCount: 0,
      lastError: null,
    );
    await _metaBox.put(recordKey, updated.toMap());
  }

  @override
  Future<bool> isExpired(String recordKey, {DateTime? now}) async {
    final meta = await getMeta(recordKey);
    if (meta == null) return true;
    return CachePolicy.isExpired(expiresAt: meta.expiresAt, now: now ?? DateTime.now());
  }

  @override
  Future<bool> isStale(String recordKey, {DateTime? now}) async {
    final meta = await getMeta(recordKey);
    if (meta == null) return true;
    return CachePolicy.isStale(expiresAt: meta.expiresAt, now: now ?? DateTime.now());
  }

  @override
  Future<void> invalidate(String recordKey) async {
    await _metaBox.delete(recordKey);
  }
}
