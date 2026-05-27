import 'package:musee/core/cache/models/cache_entity_type.dart';

enum CacheSyncState { synced, pending, failed }

class CacheRecordMeta {
  final String recordKey;
  final CacheEntityType entityType;
  final DateTime fetchedAt;
  final DateTime expiresAt;
  final DateTime? serverUpdatedAt;
  final DateTime? lastAccessedAt;
  final DateTime? lastSyncedAt;
  final CacheSyncState syncState;
  final int retryCount;
  final String? lastError;

  const CacheRecordMeta({
    required this.recordKey,
    required this.entityType,
    required this.fetchedAt,
    required this.expiresAt,
    required this.syncState,
    this.serverUpdatedAt,
    this.lastAccessedAt,
    this.lastSyncedAt,
    this.retryCount = 0,
    this.lastError,
  });

  CacheRecordMeta copyWith({
    DateTime? fetchedAt,
    DateTime? expiresAt,
    DateTime? serverUpdatedAt,
    DateTime? lastAccessedAt,
    DateTime? lastSyncedAt,
    CacheSyncState? syncState,
    int? retryCount,
    String? lastError,
  }) {
    return CacheRecordMeta(
      recordKey: recordKey,
      entityType: entityType,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncState: syncState ?? this.syncState,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'record_key': recordKey,
      'entity_type': entityType.name,
      'fetched_at': fetchedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'server_updated_at': serverUpdatedAt?.toIso8601String(),
      'last_accessed_at': lastAccessedAt?.toIso8601String(),
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'sync_state': syncState.name,
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  static CacheRecordMeta? fromMap(Map<String, dynamic> map) {
    final entityTypeRaw = map['entity_type']?.toString();
    final syncStateRaw = map['sync_state']?.toString();
    final fetchedAtRaw = map['fetched_at']?.toString();
    final expiresAtRaw = map['expires_at']?.toString();
    final recordKeyRaw = map['record_key']?.toString();

    if (recordKeyRaw == null || fetchedAtRaw == null || expiresAtRaw == null) {
      return null;
    }

    final fetchedAt = DateTime.tryParse(fetchedAtRaw);
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (fetchedAt == null || expiresAt == null) return null;

    final entityType = CacheEntityType.values.where((value) {
      return value.name == entityTypeRaw;
    }).firstOrNull;

    final syncState = CacheSyncState.values.where((value) {
      return value.name == syncStateRaw;
    }).firstOrNull;

    if (entityType == null || syncState == null) {
      return null;
    }

    return CacheRecordMeta(
      recordKey: recordKeyRaw,
      entityType: entityType,
      fetchedAt: fetchedAt,
      expiresAt: expiresAt,
      serverUpdatedAt: _tryParse(map['server_updated_at']),
      lastAccessedAt: _tryParse(map['last_accessed_at']),
      lastSyncedAt: _tryParse(map['last_synced_at']),
      syncState: syncState,
      retryCount: (map['retry_count'] is num)
          ? (map['retry_count'] as num).toInt()
          : int.tryParse(map['retry_count']?.toString() ?? '') ?? 0,
      lastError: map['last_error']?.toString(),
    );
  }

  static DateTime? _tryParse(dynamic raw) {
    final value = raw?.toString();
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
