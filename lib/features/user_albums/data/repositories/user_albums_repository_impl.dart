import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/user_media_detail_cache_service.dart';
import 'package:musee/core/common/services/connectivity_service.dart';
import 'package:musee/core/providers/music_provider_registry.dart';
import 'package:musee/features/user_albums/data/datasources/user_albums_remote_data_source.dart';
import 'package:musee/features/user_albums/domain/entities/user_album.dart';
import 'package:musee/features/user_albums/domain/repository/user_albums_repository.dart';

class UserAlbumsRepositoryImpl implements UserAlbumsRepository {
  final UserAlbumsRemoteDataSource _remote;
  final MusicProviderRegistry _registry;
  final TrackCacheService _trackCache;
  final ConnectivityService _connectivity;
  final UserMediaDetailCacheService _detailCache;

  static const Duration _detailTtl = Duration(hours: 6);

  UserAlbumsRepositoryImpl(
    this._remote,
    this._registry,
    this._trackCache,
    this._connectivity,
    this._detailCache,
  );

  @override
  Future<UserAlbumDetail> getAlbum(
    String albumId, {
    bool forceRefresh = false,
  }) async {
    final cachedPayload = await _detailCache.getAlbum(albumId);

    if (!forceRefresh && cachedPayload != null && !_isExpired(cachedPayload)) {
      return _albumFromCachePayload(cachedPayload);
    }

    final isOnline = await _connectivity.checkConnectivity();
    if (!isOnline) {
      if (cachedPayload != null) {
        return _albumFromCachePayload(cachedPayload);
      }
      throw Exception(
        'Album not available offline yet. Open this album once while online to cache it.',
      );
    }

    final isUuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(albumId);

    if (!isUuid) {
      final album = await _registry.getAlbumWithTracks(albumId);
      if (album == null) {
        throw Exception('External album not found');
      }

      final detail = UserAlbumDetail(
        albumId: album.prefixedId,
        title: album.title,
        coverUrl: album.coverUrl,
        releaseDate: DateTime.now().toIso8601String(),
        artists: album.artists
            .map(
              (a) => UserAlbumArtist(
                artistId: a.prefixedId,
                name: a.name,
                avatarUrl: null,
              ),
            )
            .toList(),
        tracks: (album.tracks ?? [])
            .map(
              (t) => UserAlbumTrack(
                trackId: t.prefixedId,
                title: t.title,
                duration: t.durationSeconds ?? 0,
                isExplicit: t.isExplicit,
                artists: t.artists
                    .map(
                      (a) => UserAlbumArtist(
                        artistId: a.prefixedId,
                        name: a.name,
                        avatarUrl: null,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList(),
      );

      await _detailCache.cacheAlbum(albumId, _albumToCachePayload(detail));
      await _seedTrackMetadata(detail);
      return _withTrackCacheFlags(detail, isFromCache: false);
    }

    final dto = await _remote.getAlbum(albumId);
    final detail = UserAlbumDetail(
      albumId: dto.albumId,
      title: dto.title,
      coverUrl: dto.coverUrl,
      releaseDate: dto.releaseDate,
      artists: dto.artists
          .map(
            (a) => UserAlbumArtist(
              artistId: a.artistId,
              name: a.name,
              avatarUrl: a.avatarUrl,
            ),
          )
          .toList(),
      tracks: dto.tracks
          .map(
            (t) => UserAlbumTrack(
              trackId: t.trackId,
              title: t.title,
              duration: t.duration,
              isExplicit: t.isExplicit,
              artists: t.artists
                  .map(
                    (a) => UserAlbumArtist(
                      artistId: a.artistId,
                      name: a.name,
                      avatarUrl: a.avatarUrl,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );

    await _detailCache.cacheAlbum(albumId, _albumToCachePayload(detail));
    await _seedTrackMetadata(detail);
    return _withTrackCacheFlags(detail, isFromCache: false);
  }

  bool _isExpired(Map<String, dynamic> payload) {
    final cachedAtIso = payload['cached_at']?.toString();
    if (cachedAtIso == null || cachedAtIso.isEmpty) return true;

    final cachedAt = DateTime.tryParse(cachedAtIso);
    if (cachedAt == null) return true;

    return DateTime.now().difference(cachedAt) >= _detailTtl;
  }

  Future<UserAlbumDetail> _albumFromCachePayload(
    Map<String, dynamic> payload,
  ) async {
    final rawArtists = payload['artists'];
    final artists = rawArtists is List
        ? rawArtists
            .whereType<Map>()
            .map(
              (entry) => UserAlbumArtist(
                artistId: entry['artist_id']?.toString() ?? '',
                name: entry['name']?.toString(),
                avatarUrl: entry['avatar_url']?.toString(),
              ),
            )
            .toList()
        : const <UserAlbumArtist>[];

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
                        (artist) => UserAlbumArtist(
                          artistId: artist['artist_id']?.toString() ?? '',
                          name: artist['name']?.toString(),
                          avatarUrl: artist['avatar_url']?.toString(),
                        ),
                      )
                      .toList()
                  : const <UserAlbumArtist>[];

              return UserAlbumTrack(
                trackId: entry['track_id']?.toString() ?? '',
                title: entry['title']?.toString() ?? 'Unknown title',
                duration: (entry['duration'] is num)
                    ? (entry['duration'] as num).toInt()
                    : int.tryParse(entry['duration']?.toString() ?? '') ?? 0,
                isExplicit: entry['is_explicit'] == true,
                artists: trackArtists,
              );
            })
            .toList()
        : const <UserAlbumTrack>[];

    final detail = UserAlbumDetail(
      albumId: payload['album_id']?.toString() ?? '',
      title: payload['title']?.toString() ?? 'Album',
      coverUrl: payload['cover_url']?.toString(),
      releaseDate: payload['release_date']?.toString(),
      artists: artists,
      tracks: tracks,
      isFromCache: true,
    );

    return _withTrackCacheFlags(detail, isFromCache: true);
  }

  Map<String, dynamic> _albumToCachePayload(UserAlbumDetail detail) {
    return {
      'album_id': detail.albumId,
      'title': detail.title,
      'cover_url': detail.coverUrl,
      'release_date': detail.releaseDate,
      'artists': detail.artists
          .map(
            (artist) => {
              'artist_id': artist.artistId,
              'name': artist.name,
              'avatar_url': artist.avatarUrl,
            },
          )
          .toList(),
      'tracks': detail.tracks
          .map(
            (track) => {
              'track_id': track.trackId,
              'title': track.title,
              'duration': track.duration,
              'is_explicit': track.isExplicit,
              'artists': track.artists
                  .map(
                    (artist) => {
                      'artist_id': artist.artistId,
                      'name': artist.name,
                      'avatar_url': artist.avatarUrl,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };
  }

  Future<UserAlbumDetail> _withTrackCacheFlags(
    UserAlbumDetail detail, {
    required bool isFromCache,
  }) async {
    final cachedTrackIds = <String>{};
    final offlineTrackIds = <String>{};

    for (final track in detail.tracks) {
      final cached = await _trackCache.getTrack(track.trackId);
      if (cached == null) continue;
      cachedTrackIds.add(track.trackId);
      if (cached.isAvailableOffline) {
        offlineTrackIds.add(track.trackId);
      }
    }

    return UserAlbumDetail(
      albumId: detail.albumId,
      title: detail.title,
      coverUrl: detail.coverUrl,
      releaseDate: detail.releaseDate,
      artists: detail.artists,
      tracks: detail.tracks,
      isFromCache: isFromCache,
      cachedTrackIds: cachedTrackIds,
      offlineTrackIds: offlineTrackIds,
    );
  }

  Future<void> _seedTrackMetadata(UserAlbumDetail detail) async {
    await _trackCache.cacheAlbum(
      CachedAlbum()
        ..albumId = detail.albumId
        ..title = detail.title
        ..coverUrl = detail.coverUrl
        ..releaseDate = detail.releaseDate
        ..artistName = detail.artists.isNotEmpty
            ? (detail.artists.first.name ?? 'Unknown Artist')
            : 'Unknown Artist'
        ..trackIds = detail.tracks.map((t) => t.trackId).toList()
        ..cachedAt = DateTime.now()
        ..sourceProvider = 'musee',
    );

    for (final track in detail.tracks) {
      final existing = await _trackCache.getTrack(track.trackId);
      await _trackCache.cacheTrack(
        CachedTrack()
          ..trackId = track.trackId
          ..title = track.title
          ..albumId = detail.albumId
          ..albumTitle = detail.title
          ..albumCoverUrl = detail.coverUrl
          ..artistName = track.artists.isNotEmpty
              ? track.artists.map((a) => a.name ?? 'Unknown Artist').join(', ')
              : 'Unknown Artist'
          ..durationSeconds = track.duration
          ..isExplicit = track.isExplicit
          ..streamingUrl = existing?.streamingUrl
          ..cachedAt = existing?.cachedAt ?? DateTime.now()
          ..lastPlayedAt = existing?.lastPlayedAt
          ..sourceProvider = existing?.sourceProvider ?? 'musee'
          ..playCount = existing?.playCount ?? 0
          ..localAudioPath = existing?.localAudioPath
          ..audioSizeBytes = existing?.audioSizeBytes ?? 0
          ..localImagePath = existing?.localImagePath,
      );
    }
  }
}
