import 'package:musee/core/cache/models/cached_track.dart';
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

  static const Duration _detailTtl = Duration(hours: 6);

  UserPlaylistsRepositoryImpl(
    this._remote,
    this._trackCache,
    this._connectivity,
    this._detailCache,
  );

  @override
  Future<UserPlaylistDetail> getPlaylist(
    String playlistId, {
    bool forceRefresh = false,
  }) async {
    final cachedPayload = await _detailCache.getPlaylist(playlistId);

    if (!forceRefresh && cachedPayload != null && !_isExpired(cachedPayload)) {
      return _playlistFromCachePayload(cachedPayload);
    }

    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline && cachedPayload != null) {
      return _playlistFromCachePayload(cachedPayload);
    }

    try {
      final dto = await _remote.getPlaylist(playlistId);
      final detail = _mapDtoToEntity(dto);

      await _detailCache.cachePlaylist(playlistId, _playlistToCachePayload(detail));
      await _seedTrackMetadata(detail);
      return _withTrackCacheFlags(detail, isFromCache: false);
    } catch (_) {
      if (cachedPayload != null) {
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
    await _detailCache.cachePlaylist(detail.playlistId, _playlistToCachePayload(detail));
    return detail;
  }

  @override
  Future<UserPlaylistDetail> joinCollaborativePlaylist(String playlistId) async {
    final dto = await _remote.joinCollaborativePlaylist(playlistId);
    final detail = _mapDtoToEntity(dto);
    await _detailCache.cachePlaylist(detail.playlistId, _playlistToCachePayload(detail));
    return detail;
  }

  @override
  Future<UserPlaylistDetail> addTrackToPlaylist(String playlistId, String trackId) async {
    final dto = await _remote.addTrackToPlaylist(playlistId, trackId);
    final detail = _mapDtoToEntity(dto);
    await _detailCache.cachePlaylist(detail.playlistId, _playlistToCachePayload(detail));
    return detail;
  }

  @override
  Future<void> removeTrackFromPlaylist(String playlistId, String trackId) async {
    await _remote.removeTrackFromPlaylist(playlistId, trackId);
  }

  @override
  Future<List<UserPlaylistDetail>> getPlaylists() async {
    final dtos = await _remote.getPlaylists();
    return dtos.map(_mapDtoToEntity).toList();
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    await _remote.deletePlaylist(playlistId);
    await _detailCache.invalidatePlaylist(playlistId);
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
    await _detailCache.cachePlaylist(detail.playlistId, _playlistToCachePayload(detail));
    return detail;
  }

  bool _isExpired(Map<String, dynamic> payload) {
    final cachedAtIso = payload['cached_at']?.toString();
    if (cachedAtIso == null || cachedAtIso.isEmpty) return true;

    final cachedAt = DateTime.tryParse(cachedAtIso);
    if (cachedAt == null) return true;

    return DateTime.now().difference(cachedAt) >= _detailTtl;
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
        ? rawTracks
            .whereType<Map>()
            .map((entry) {
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
                artists: trackArtists,
              );
            })
            .toList()
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

  Future<Set<String>> _getCachedTrackIds(List<UserPlaylistTrack> tracks) async {
    final cached = <String>{};
    for (final track in tracks) {
      final cachedTrack = await _trackCache.getTrack(track.trackId);
      if (cachedTrack != null) cached.add(track.trackId);
    }
    return cached;
  }

  Future<Set<String>> _getOfflineTrackIds(List<UserPlaylistTrack> tracks) async {
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
      await _trackCache.cacheTrack(
        CachedTrack()
          ..trackId = track.trackId
          ..title = track.title
          ..durationSeconds = track.duration
          ..isExplicit = track.isExplicit
          ..artistName = track.artists.map((a) => a.name ?? 'Unknown').join(', ')
          ..albumCoverUrl = detail.coverUrl
          ..cachedAt = DateTime.now(),
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
}
