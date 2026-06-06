import 'dart:async';
import 'package:musee/core/cache/cache_config.dart';
import 'package:musee/core/cache/models/cache_entity_type.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/cache/services/media_cache_meta_service.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/user_media_detail_cache_service.dart';
import 'package:musee/core/common/services/connectivity_service.dart';
import 'package:musee/features/user_playlists/data/datasources/user_playlists_remote_data_source.dart';
import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';

class UserPlaylistsRepositoryImpl implements UserPlaylistsRepository {
  final UserPlaylistsRemoteDataSource _remote;
  final TrackCacheService _trackCache;
  final ConnectivityService _connectivity;
  final UserMediaDetailCacheService _detailCache;
  final MediaCacheMetaService _cacheMeta;

  UserPlaylistsRepositoryImpl(
    this._remote,
    this._trackCache,
    this._connectivity,
    this._detailCache,
    this._cacheMeta,
  );

  @override
  Future<UserPlaylistDetail> getPlaylist(
    String playlistId, {
    bool forceRefresh = false,
  }) async {
    final recordKey = _cacheMeta.buildRecordKey(
      entityType: CacheEntityType.playlist,
      entityId: playlistId,
    );

    final cachedPayload = await _detailCache.getPlaylist(playlistId);
    if (!forceRefresh &&
        cachedPayload != null &&
        !(await _isExpired(recordKey, cachedPayload))) {
      await _cacheMeta.markAccessed(recordKey);
      return _playlistFromCachePayload(cachedPayload);
    }

    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline && cachedPayload != null) {
      await _cacheMeta.markAccessed(recordKey);
      return _playlistFromCachePayload(cachedPayload);
    }

    try {
      final dto = await _remote.getPlaylist(playlistId);
      final detail = _mapDtoToEntity(dto);

      await _detailCache.cachePlaylist(
        playlistId,
        _playlistToCachePayload(detail),
      );
      await _cacheMeta.upsertMeta(
        recordKey: recordKey,
        entityType: CacheEntityType.playlist,
      );
      await _seedTrackMetadata(detail);
      return _withTrackCacheFlags(detail, isFromCache: false);
    } catch (_) {
      if (cachedPayload != null) {
        await _cacheMeta.markAccessed(recordKey);
        return _playlistFromCachePayload(cachedPayload);
      }

      if (!isOnline) {
        throw Exception(
          'Playlist not available offline yet. Open this playlist once while online to cache it.',
        );
      }

      rethrow;
    }
  }

  @override
  Future<UserPlaylistDetail> createPlaylist({
    required String name,
    String? description,
    required bool isPublic,
    required bool isCollaborative,
    String? coverPath,
  }) async {
    final dto = await _remote.createPlaylist(
      name: name,
      description: description,
      isPublic: isPublic,
      isCollaborative: isCollaborative,
      coverPath: coverPath,
    );
    final detail = _mapDtoToEntity(dto);
    await _detailCache.cachePlaylist(
      detail.playlistId,
      _playlistToCachePayload(detail),
    );
    await _cacheMeta.upsertMeta(
      recordKey: _cacheMeta.buildRecordKey(
        entityType: CacheEntityType.playlist,
        entityId: detail.playlistId,
      ),
      entityType: CacheEntityType.playlist,
    );
    return detail;
  }

  @override
  Future<UserPlaylistDetail> joinCollaborativePlaylist(
    String playlistId,
  ) async {
    final dto = await _remote.joinCollaborativePlaylist(playlistId);
    final detail = _mapDtoToEntity(dto);
    await _detailCache.cachePlaylist(
      detail.playlistId,
      _playlistToCachePayload(detail),
    );
    await _cacheMeta.upsertMeta(
      recordKey: _cacheMeta.buildRecordKey(
        entityType: CacheEntityType.playlist,
        entityId: detail.playlistId,
      ),
      entityType: CacheEntityType.playlist,
    );
    return detail;
  }

  @override
  Future<UserPlaylistDetail> addTrackToPlaylist(
    String playlistId,
    String trackId,
  ) async {
    // Optimistic update: if we have a cached playlist, append a placeholder
    // track and return it immediately while syncing to the backend in
    // the background.
    final cachedPayload = await _detailCache.getPlaylist(playlistId);
    UserPlaylistDetail? optimistic;

    if (cachedPayload != null) {
      try {
        final cachedDetail = await _playlistFromCachePayload(cachedPayload);
        final alreadyPresent = cachedDetail.tracks.any((t) => t.trackId == trackId);
        final placeholderTrack = await _buildOptimisticTrack(
          trackId,
          playlistCoverUrl: cachedDetail.coverUrl,
        );

        final newTracks = alreadyPresent
            ? cachedDetail.tracks
                .map(
                  (t) => t.trackId == trackId
                      ? UserPlaylistTrack(
                          trackId: t.trackId,
                          title: t.title,
                          duration: t.duration,
                          isExplicit: t.isExplicit,
                          isSyncing: true,
                          coverUrl: t.coverUrl,
                          artists: t.artists,
                        )
                      : t,
                )
                .toList(growable: false)
            : (List<UserPlaylistTrack>.from(cachedDetail.tracks)
              ..add(placeholderTrack));

        optimistic = UserPlaylistDetail(
          playlistId: cachedDetail.playlistId,
          name: cachedDetail.name,
          coverUrl: cachedDetail.coverUrl,
          description: cachedDetail.description,
          artists: cachedDetail.artists,
          tracks: newTracks,
          isPublic: cachedDetail.isPublic,
          isCollaborative: cachedDetail.isCollaborative,
          collaborators: cachedDetail.collaborators,
          totalTracks: newTracks.length,
          totalDuration: newTracks.fold<int>(0, (sum, t) => sum + t.duration),
          createdAt: cachedDetail.createdAt,
        );

        await _detailCache.cachePlaylist(optimistic.playlistId, _playlistToCachePayload(optimistic));
        await _cacheMeta.markSyncPending(
          _cacheMeta.buildRecordKey(
            entityType: CacheEntityType.playlist,
            entityId: optimistic.playlistId,
          ),
        );
        unawaited(_seedTrackMetadata(optimistic));
      } catch (_) {}
    }

    // Background sync: call remote and reconcile cache when it completes.
    () async {
      try {
        final dto = await _remote.addTrackToPlaylist(playlistId, trackId);
        final detail = _mapDtoToEntity(dto);
        await _detailCache.cachePlaylist(detail.playlistId, _playlistToCachePayload(detail));
        await _cacheMeta.markSynced(
          _cacheMeta.buildRecordKey(
            entityType: CacheEntityType.playlist,
            entityId: detail.playlistId,
          ),
        );
      } catch (_) {
        try {
          final isOnline = await _connectivity.checkConnectivity();
          if (isOnline) await getPlaylist(playlistId, forceRefresh: true);
        } catch (_) {}
      }
    }();

    if (optimistic != null) return optimistic;

    final dto = await _remote.addTrackToPlaylist(playlistId, trackId);
    final detail = _mapDtoToEntity(dto);
    await _detailCache.cachePlaylist(
      detail.playlistId,
      _playlistToCachePayload(detail),
    );
    return detail;
  }

  @override
  Future<void> removeTrackFromPlaylist(
    String playlistId,
    String trackId,
  ) async {
    // Optimistically remove the track from cached playlist if present
    final cachedPayload = await _detailCache.getPlaylist(playlistId);
    if (cachedPayload != null) {
      try {
        final cachedDetail = await _playlistFromCachePayload(cachedPayload);
        final newTracks = List<UserPlaylistTrack>.from(cachedDetail.tracks)
          ..removeWhere((t) => t.trackId == trackId);
        final updated = UserPlaylistDetail(
          playlistId: cachedDetail.playlistId,
          name: cachedDetail.name,
          coverUrl: cachedDetail.coverUrl,
          description: cachedDetail.description,
          artists: cachedDetail.artists,
          tracks: newTracks,
          isPublic: cachedDetail.isPublic,
          isCollaborative: cachedDetail.isCollaborative,
          collaborators: cachedDetail.collaborators,
          totalTracks: newTracks.length,
          totalDuration: newTracks.fold<int>(0, (s, t) => s + t.duration),
          createdAt: cachedDetail.createdAt,
        );
        await _detailCache.cachePlaylist(updated.playlistId, _playlistToCachePayload(updated));
        await _cacheMeta.markSyncPending(
          _cacheMeta.buildRecordKey(
            entityType: CacheEntityType.playlist,
            entityId: updated.playlistId,
          ),
        );
      } catch (_) {}
    }

    // Background removal and reconcile
    () async {
      try {
        await _remote.removeTrackFromPlaylist(playlistId, trackId);
        try {
          await getPlaylist(playlistId, forceRefresh: true);
        } catch (_) {}
      } catch (_) {
        try {
          await getPlaylist(playlistId, forceRefresh: true);
        } catch (_) {}
      }
    }();
  }

  @override
  Future<List<UserPlaylistDetail>> getPlaylists() async {
    final cachedPlaylists = await _loadCachedPlaylists();
    final cachedById = {
      for (final playlist in cachedPlaylists) playlist.playlistId: playlist,
    };

    try {
      final dtos = await _remote.getPlaylists();
      final merged = <UserPlaylistDetail>[];
      final toCache = <UserPlaylistDetail>[];

      for (final dto in dtos) {
        final remotePlaylist = _mapDtoToEntity(dto);
        final cachedPlaylist = cachedById.remove(remotePlaylist.playlistId);
        final playlist = _mergePlaylistDetails(remotePlaylist, cachedPlaylist);
        merged.add(playlist);
        toCache.add(playlist);
      }

      merged.addAll(cachedById.values);
      toCache.addAll(cachedById.values);

      await Future.wait(
        toCache.map(
          (playlist) => _detailCache.cachePlaylist(
            playlist.playlistId,
            _playlistToCachePayload(playlist),
          ),
        ),
      );

      return merged;
    } catch (_) {
      if (cachedPlaylists.isNotEmpty) {
        return cachedPlaylists;
      }
      rethrow;
    }
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await _remote.deletePlaylist(playlistId);
    await _detailCache.invalidatePlaylist(playlistId);
    await _cacheMeta.invalidate(
      _cacheMeta.buildRecordKey(
        entityType: CacheEntityType.playlist,
        entityId: playlistId,
      ),
    );
  }

  @override
  Future<UserPlaylistDetail> updatePlaylist({
    required String playlistId,
    String? name,
    String? description,
    bool? isPublic,
    bool? isCollaborative,
    String? coverPath,
  }) async {
    final dto = await _remote.updatePlaylist(
      playlistId: playlistId,
      name: name,
      description: description,
      isPublic: isPublic,
      isCollaborative: isCollaborative,
      coverPath: coverPath,
    );
    final detail = _mapDtoToEntity(dto);
    await _detailCache.cachePlaylist(
      detail.playlistId,
      _playlistToCachePayload(detail),
    );
    await _cacheMeta.upsertMeta(
      recordKey: _cacheMeta.buildRecordKey(
        entityType: CacheEntityType.playlist,
        entityId: detail.playlistId,
      ),
      entityType: CacheEntityType.playlist,
    );
    return detail;
  }

  Future<bool> _isExpired(String recordKey, Map<String, dynamic> payload) async {
    final existingMeta = await _cacheMeta.getMeta(recordKey);
    if (existingMeta != null) {
      return _cacheMeta.isExpired(recordKey);
    }

    final cachedAtIso = payload['cached_at']?.toString();
    if (cachedAtIso == null || cachedAtIso.isEmpty) return true;

    final cachedAt = DateTime.tryParse(cachedAtIso);
    if (cachedAt == null) return true;

    return DateTime.now().difference(cachedAt) >= CacheConfig.detailPayloadMaxAge;
  }

  Future<UserPlaylistDetail> _playlistFromCachePayload(
    Map<String, dynamic> payload,
  ) async {
    final rawArtists = payload['artists'];
    final artists = rawArtists is List
        ? rawArtists
              .whereType<Map>()
              .map(
                (entry) => UserPlaylistArtist(
                  artistId: entry['artist_id']?.toString() ?? '',
                  name: entry['name']?.toString(),
                  avatarUrl: entry['avatar_url']?.toString(),
                ),
              )
              .toList()
        : const <UserPlaylistArtist>[];

    final rawCollaborators = payload['collaborators'];
    final collaborators = rawCollaborators is List
        ? rawCollaborators
              .whereType<Map>()
              .map(
                (entry) => UserPlaylistArtist(
                  artistId: entry['artist_id']?.toString() ?? '',
                  name: entry['name']?.toString(),
                  avatarUrl: entry['avatar_url']?.toString(),
                ),
              )
              .toList()
        : const <UserPlaylistArtist>[];

    final rawTracks = payload['tracks'];
    final tracks = rawTracks is List
        ? rawTracks.whereType<Map>().map((entry) {
            final trackArtistsRaw = entry['artists'];
            final trackArtists = trackArtistsRaw is List
                ? trackArtistsRaw
                      .whereType<Map>()
                      .map(
                        (artist) => UserPlaylistArtist(
                          artistId: artist['artist_id']?.toString() ?? '',
                          name: artist['name']?.toString(),
                          avatarUrl: artist['avatar_url']?.toString(),
                        ),
                      )
                      .toList()
                : const <UserPlaylistArtist>[];

            return UserPlaylistTrack(
              trackId: entry['track_id']?.toString() ?? '',
              title: entry['title']?.toString() ?? 'Unknown title',
              duration: (entry['duration'] is num)
                  ? (entry['duration'] as num).toInt()
                  : int.tryParse(entry['duration']?.toString() ?? '') ?? 0,
              isExplicit: (entry['is_explicit'] ?? false) as bool,
              isSyncing: _asBool(entry['is_syncing']),
              coverUrl:
                  entry['cover_url']?.toString() ??
                  entry['image_url']?.toString() ??
                  entry['album_cover_url']?.toString() ??
                  (entry['album'] is Map
                      ? (entry['album']['cover_url']?.toString())
                      : null),
              artists: trackArtists,
            );
          }).toList()
        : const <UserPlaylistTrack>[];

    return UserPlaylistDetail(
      playlistId: payload['playlist_id']?.toString() ?? '',
      name: payload['name']?.toString() ?? 'Unknown Playlist',
      coverUrl: payload['cover_url']?.toString(),
      description: payload['description']?.toString(),
      artists: artists,
      tracks: tracks,
      isPublic: (payload['is_public'] ?? false) as bool,
      isCollaborative: (payload['is_collaborative'] ?? false) as bool,
      collaborators: collaborators,
      totalTracks: (payload['total_tracks'] ?? tracks.length) as int,
      totalDuration: (payload['total_duration'] ?? 0) as int,
      createdAt: payload['created_at']?.toString(),
      isFromCache: true,
      cachedTrackIds: await _getCachedTrackIds(tracks),
      offlineTrackIds: await _getOfflineTrackIds(tracks),
    );
  }

  Future<List<UserPlaylistDetail>> _loadCachedPlaylists() async {
    final payloads = await _detailCache.getAllPlaylists();
    return Future.wait(payloads.map(_playlistFromCachePayload));
  }

  UserPlaylistDetail _mergePlaylistDetails(
    UserPlaylistDetail remote,
    UserPlaylistDetail? cached,
  ) {
    if (cached == null) {
      return remote;
    }

    final tracks = remote.tracks.isNotEmpty ? remote.tracks : cached.tracks;
    final totalTracks = remote.totalTracks > 0
        ? remote.totalTracks
        : (tracks.isNotEmpty ? tracks.length : cached.totalTracks);

    return UserPlaylistDetail(
      playlistId: remote.playlistId,
      name: remote.name.isNotEmpty ? remote.name : cached.name,
      coverUrl: remote.coverUrl ?? cached.coverUrl,
      description: remote.description ?? cached.description,
      artists: remote.artists.isNotEmpty ? remote.artists : cached.artists,
      tracks: tracks,
      isPublic: remote.isPublic,
      isCollaborative: remote.isCollaborative,
      collaborators: remote.collaborators.isNotEmpty
          ? remote.collaborators
          : cached.collaborators,
      totalTracks: totalTracks,
      totalDuration: remote.totalDuration > 0
          ? remote.totalDuration
          : cached.totalDuration,
      createdAt: remote.createdAt ?? cached.createdAt,
    );
  }

  Future<Set<String>> _getCachedTrackIds(List<UserPlaylistTrack> tracks) async {
    final cached = <String>{};
    for (final track in tracks) {
      final cachedTrack = await _trackCache.getTrack(track.trackId);
      if (cachedTrack != null) cached.add(track.trackId);
    }
    return cached;
  }

  Future<Set<String>> _getOfflineTrackIds(
    List<UserPlaylistTrack> tracks,
  ) async {
    final offline = <String>{};
    final offlineAvailable = await _trackCache.getOfflineAvailable();
    final offlineIds = {for (var t in offlineAvailable) t.trackId};
    for (final track in tracks) {
      if (offlineIds.contains(track.trackId)) {
        offline.add(track.trackId);
      }
    }
    return offline;
  }

  Future<void> _seedTrackMetadata(UserPlaylistDetail detail) async {
    for (final track in detail.tracks) {
      final existing = await _trackCache.getTrack(track.trackId);
      await _trackCache.cacheTrack(
        CachedTrack()
          ..trackId = track.trackId
          ..title = track.title
          ..durationSeconds = track.duration
          ..isExplicit = track.isExplicit
          ..artistName = track.artists
              .map((a) => a.name ?? 'Unknown')
              .join(', ')
          ..albumCoverUrl = track.coverUrl ?? detail.coverUrl
          ..cachedAt = existing?.cachedAt ?? DateTime.now()
          ..lastPlayedAt = existing?.lastPlayedAt
          ..sourceProvider = existing?.sourceProvider ?? 'musee'
          ..playCount = existing?.playCount ?? 0
          ..localAudioPath = existing?.localAudioPath
          ..audioSizeBytes = existing?.audioSizeBytes ?? 0
          ..localImagePath = existing?.localImagePath
          ..isDownloaded = existing?.isDownloaded ?? false,
      );
    }
  }

  UserPlaylistDetail _withTrackCacheFlags(
    UserPlaylistDetail detail, {
    required bool isFromCache,
  }) {
    return detail;
  }

  UserPlaylistDetail _mapDtoToEntity(UserPlaylistDetailDTO dto) {
    return UserPlaylistDetail(
      playlistId: dto.playlistId,
      name: dto.name,
      coverUrl: dto.coverUrl,
      description: dto.description,
      artists: dto.artists
          .map(
            (a) => UserPlaylistArtist(
              artistId: a.artistId,
              name: a.name,
              avatarUrl: a.avatarUrl,
            ),
          )
          .toList(),
      tracks: dto.tracks
          .map(
            (t) => UserPlaylistTrack(
              trackId: t.trackId,
              title: t.title,
              duration: t.duration,
              isExplicit: t.isExplicit,
              isSyncing: false,
              coverUrl: t.coverUrl,
              artists: t.artists
                  .map(
                    (a) => UserPlaylistArtist(
                      artistId: a.artistId,
                      name: a.name,
                      avatarUrl: a.avatarUrl,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      isPublic: dto.isPublic,
      isCollaborative: dto.isCollaborative,
      collaborators: dto.collaborators
          .map(
            (c) => UserPlaylistArtist(
              artistId: c.artistId,
              name: c.name,
              avatarUrl: c.avatarUrl,
            ),
          )
          .toList(),
      totalTracks: dto.totalTracks,
      totalDuration: dto.totalDuration,
      createdAt: dto.createdAt,
    );
  }

  Map<String, dynamic> _playlistToCachePayload(UserPlaylistDetail playlist) {
    return {
      'playlist_id': playlist.playlistId,
      'name': playlist.name,
      'cover_url': playlist.coverUrl,
      'description': playlist.description,
      'creator_name': playlist.artists.isNotEmpty
          ? playlist.artists.first.name
          : null,
      'artists': playlist.artists
          .map(
            (a) => {
              'artist_id': a.artistId,
              'name': a.name,
              'avatar_url': a.avatarUrl,
            },
          )
          .toList(),
      'tracks': playlist.tracks
          .map(
            (t) => {
              'track_id': t.trackId,
              'title': t.title,
              'duration': t.duration,
              'is_explicit': t.isExplicit,
              'is_syncing': t.isSyncing,
              'cover_url': t.coverUrl,
              'artists': t.artists
                  .map(
                    (a) => {
                      'artist_id': a.artistId,
                      'name': a.name,
                      'avatar_url': a.avatarUrl,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
      'is_public': playlist.isPublic,
      'is_collaborative': playlist.isCollaborative,
      'collaborators': playlist.collaborators
          .map(
            (c) => {
              'artist_id': c.artistId,
              'name': c.name,
              'avatar_url': c.avatarUrl,
            },
          )
          .toList(),
      'total_tracks': playlist.totalTracks,
      'total_duration': playlist.totalDuration,
      'created_at': playlist.createdAt,
    };
  }

  Future<UserPlaylistTrack> _buildOptimisticTrack(
    String trackId, {
    String? playlistCoverUrl,
  }) async {
    final cachedTrack = await _trackCache.getTrack(trackId);
    final cachedTitle = cachedTrack?.title.trim();
    final cachedArtist = cachedTrack?.artistName.trim();

    if (cachedTitle != null && cachedTitle.isNotEmpty) {
      return UserPlaylistTrack(
        trackId: trackId,
        title: cachedTitle,
        duration: cachedTrack?.durationSeconds ?? 0,
        isExplicit: cachedTrack?.isExplicit ?? false,
        isSyncing: true,
        coverUrl: cachedTrack?.albumCoverUrl ?? playlistCoverUrl,
        artists: [
          UserPlaylistArtist(
            artistId: cachedTrack != null
                ? 'cached:${cachedTrack.prefixedId}'
                : 'cached:$trackId',
            name: (cachedArtist != null && cachedArtist.isNotEmpty)
                ? cachedArtist
                : 'Unknown Artist',
            avatarUrl: null,
          ),
        ],
      );
    }

    try {
      final dto = await _remote.getTrackById(trackId);
      return UserPlaylistTrack(
        trackId: dto.trackId,
        title: dto.title,
        duration: dto.duration,
        isExplicit: dto.isExplicit,
        isSyncing: true,
        coverUrl: dto.coverUrl ?? playlistCoverUrl,
        artists: dto.artists
            .map(
              (a) => UserPlaylistArtist(
                artistId: a.artistId,
                name: a.name,
                avatarUrl: a.avatarUrl,
              ),
            )
            .toList(),
      );
    } catch (_) {
      return UserPlaylistTrack(
        trackId: trackId,
        title: 'Loading track...',
        duration: 0,
        isExplicit: false,
        isSyncing: true,
        coverUrl: playlistCoverUrl,
        artists: const [
          UserPlaylistArtist(
            artistId: 'pending',
            name: 'Fetching details...',
            avatarUrl: null,
          ),
        ],
      );
    }
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      return normalized == 'true' || normalized == '1';
    }
    if (value is num) return value != 0;
    return false;
  }
}
