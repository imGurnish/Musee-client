import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/admin_albums/data/datasources/admin_albums_remote_data_source.dart';
import 'package:musee/features/admin_artists/data/datasources/admin_artists_remote_data_source.dart';
import 'package:musee/features/admin_tracks/data/datasources/admin_tracks_remote_data_source.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'jiosaavn_api_client.dart';

class ExternalImportResult {
  final String entityId;
  final bool alreadyExisted;
  final int importedTracks;

  const ExternalImportResult({
    required this.entityId,
    this.alreadyExisted = false,
    this.importedTracks = 0,
  });
}

class AdminExternalImportService {
  final JioSaavnApiClient jioApi;
  final AdminArtistsRemoteDataSource artistsApi;
  final AdminAlbumsRemoteDataSource albumsApi;
  final AdminTracksRemoteDataSource tracksApi;
  final SupabaseClient supabase;
  final dio.Dio _dio;
  String? _cachedValidRegionId;

  AdminExternalImportService({
    required this.jioApi,
    required this.artistsApi,
    required this.albumsApi,
    required this.tracksApi,
    required this.supabase,
    required dio.Dio dioClient,
  }) : _dio = dioClient;

  Future<List<JioSaavnSearchItem>> searchTracks(String query) {
    return jioApi.searchTracks(query);
  }

  Future<List<JioSaavnSearchItem>> searchAlbums(String query) {
    return jioApi.searchAlbums(query);
  }

  Future<List<JioSaavnSearchItem>> searchPlaylists(String query) {
    return jioApi.searchPlaylists(query);
  }

  Future<JioSaavnSongDetail> fetchTrackInfo(String externalTrackId) {
    return jioApi.getSongDetails(externalTrackId);
  }

  Future<JioSaavnAlbumDetail> fetchAlbumInfo(String externalAlbumId) {
    return jioApi.getAlbumDetails(externalAlbumId);
  }

  Future<JioSaavnPlaylistDetail> fetchPlaylistInfo(String externalPlaylistId) {
    return jioApi.getPlaylistDetails(externalPlaylistId);
  }

  Future<ExternalImportResult> importTrack(String externalTrackId) async {
    try {
      final song = await jioApi.getSongDetails(externalTrackId);
      return _importSong(song);
    } catch (e) {
      throw Exception(_toErrorMessage(e, fallback: 'Failed to import track'));
    }
  }

  Future<ExternalImportResult> importAlbum(String externalAlbumId) async {
    try {
      final existing = await _findExistingByExt(
        table: 'albums',
        idColumn: 'album_id',
        extColumn: 'ext_album_id',
        extId: externalAlbumId,
      );
      if (existing != null) {
        return ExternalImportResult(entityId: existing, alreadyExisted: true);
      }

      final albumDetail = await jioApi.getAlbumDetails(externalAlbumId);
      final ownerMeta = _firstValidArtist(albumDetail.artists);
      if (ownerMeta == null) {
        throw Exception('Album has no valid artist metadata to import');
      }
      final ownerArtist = await _ensureArtist(
        ownerMeta,
        contextSummary: _buildAlbumDescription(
          title: albumDetail.title,
          language: albumDetail.language,
          releaseDate: albumDetail.releaseDate,
          trackCount: albumDetail.songs.length,
        ),
      );

      final coverBytes = await jioApi.downloadImage(albumDetail.imageUrl);
      final createdAlbum = await _createAlbumWithFallback(
        title: albumDetail.title,
        artistId: ownerArtist,
        externalAlbumId: albumDetail.id,
        releaseDate: albumDetail.releaseDate,
        language: albumDetail.language,
        description: _buildAlbumDescription(
          title: albumDetail.title,
          language: albumDetail.language,
          releaseDate: albumDetail.releaseDate,
          trackCount: albumDetail.songs.length,
        ),
        externalUrl: albumDetail.permaUrl,
        imageUrl: albumDetail.imageUrl,
        externalPayload: albumDetail.rawPayload,
        coverBytes: coverBytes,
        coverFilename: coverBytes != null ? '${albumDetail.id}.jpg' : null,
      );

      for (final artist in albumDetail.artists.skip(1)) {
        if (_isUnknownArtist(artist)) continue;
        final artistId = await _ensureArtist(
          artist,
          contextSummary: _buildAlbumDescription(
            title: albumDetail.title,
            language: albumDetail.language,
            releaseDate: albumDetail.releaseDate,
            trackCount: albumDetail.songs.length,
          ),
        );
        if (artistId == ownerArtist) continue;
        try {
          await albumsApi.addArtist(
            albumId: createdAlbum.id,
            artistId: artistId,
            role: 'viewer',
          );
        } catch (_) {}
      }

      var imported = 0;
      for (final song in albumDetail.songs) {
        await _importSong(song, fallbackAlbumId: createdAlbum.id);
        imported++;
      }

      return ExternalImportResult(
        entityId: createdAlbum.id,
        importedTracks: imported,
      );
    } catch (e) {
      throw Exception(_toErrorMessage(e, fallback: 'Failed to import album'));
    }
  }

  Future<ExternalImportResult> importPlaylist(String externalPlaylistId) async {
    try {
      final existing = await _findExistingByExt(
        table: 'playlists',
        idColumn: 'playlist_id',
        extColumn: 'ext_playlist_id',
        extId: externalPlaylistId,
      );
      if (existing != null) {
        return ExternalImportResult(entityId: existing, alreadyExisted: true);
      }

      final playlist = await jioApi.getPlaylistDetails(externalPlaylistId);

      final importedTrackIds = <String>[];
      for (final song in playlist.songs) {
        final result = await _importSong(song);
        importedTrackIds.add(result.entityId);
      }

      final playlistId = await _createPlaylist(
        externalPlaylistId: playlist.id,
        title: playlist.title,
        description: playlist.subtitle,
        language: playlist.language,
        externalUrl: playlist.permaUrl,
        coverUrl: playlist.imageUrl,
        trackCount: playlist.songs.length,
        externalPayload: playlist.rawPayload,
      );

      for (final trackId in importedTrackIds.toSet()) {
        try {
          await _dio.post(
            '${AppSecrets.backendUrl}/api/admin/playlists/$playlistId/tracks',
            data: {'track_id': trackId},
            options: dio.Options(headers: _authHeader()),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'Failed adding track $trackId to playlist $playlistId: $e',
            );
          }
        }
      }

      return ExternalImportResult(
        entityId: playlistId,
        importedTracks: importedTrackIds.length,
      );
    } catch (e) {
      throw Exception(
        _toErrorMessage(e, fallback: 'Failed to import playlist'),
      );
    }
  }

  Future<ExternalImportResult> _importSong(
    JioSaavnSongDetail song, {
    String? fallbackAlbumId,
  }) async {
    final existingTrack = await _findExistingByExt(
      table: 'tracks',
      idColumn: 'track_id',
      extColumn: 'ext_track_id',
      extId: song.id,
    );
    if (existingTrack != null) {
      return ExternalImportResult(
        entityId: existingTrack,
        alreadyExisted: true,
      );
    }

    final albumId = fallbackAlbumId ?? await _ensureAlbumForSong(song);
    final artistIds = <String>[];
    for (final artist in song.artists) {
      if (_isUnknownArtist(artist)) continue;
      artistIds.add(
        await _ensureArtist(artist, contextSummary: _buildTrackArtistBio(song)),
      );
    }
    if (artistIds.isEmpty) {
      final ownerArtistId = await _findAlbumOwnerArtistId(albumId);
      if (ownerArtistId != null && ownerArtistId.isNotEmpty) {
        artistIds.add(ownerArtistId);
      }
    }
    if (artistIds.isEmpty) {
      throw Exception('Track ${song.title} has no valid artist to import');
    }

    final audio = await jioApi.downloadSongAudio(song);

    final createdTrack = await _createTrackWithFallback(
      song: song,
      albumId: albumId,
      externalAlbumId: song.albumId,
      albumImageUrl: song.imageUrl,
      audioBytes: audio.$1,
      audioFilename: audio.$2,
      artists: artistIds,
    );

    return ExternalImportResult(entityId: createdTrack.trackId);
  }

  Future<String> _ensureAlbumForSong(JioSaavnSongDetail song) async {
    final extAlbumId = song.albumId;
    if (extAlbumId == null || extAlbumId.isEmpty) {
      throw Exception('Song ${song.title} does not have a valid album id');
    }

    final existing = await _findExistingByExt(
      table: 'albums',
      idColumn: 'album_id',
      extColumn: 'ext_album_id',
      extId: extAlbumId,
    );
    if (existing != null) return existing;

    final albumDetail = await jioApi.getAlbumDetails(extAlbumId);
    final ownerMeta =
        _firstValidArtist(albumDetail.artists) ??
        _firstValidArtist(song.artists);
    if (ownerMeta == null) {
      throw Exception(
        'Song ${song.title} has no valid artist metadata to import',
      );
    }
    final ownerArtistId = await _ensureArtist(
      ownerMeta,
      contextSummary: _buildAlbumDescription(
        title: albumDetail.title.isNotEmpty
            ? albumDetail.title
            : (song.albumTitle ?? 'Album'),
        language: albumDetail.language ?? song.language,
        releaseDate: albumDetail.releaseDate ?? song.releaseDate,
        trackCount: albumDetail.songs.length,
      ),
    );

    final coverBytes = await jioApi.downloadImage(
      albumDetail.imageUrl ?? song.imageUrl,
    );
    final createdAlbum = await _createAlbumWithFallback(
      title: albumDetail.title.isNotEmpty
          ? albumDetail.title
          : (song.albumTitle ?? 'Imported Album'),
      artistId: ownerArtistId,
      externalAlbumId: extAlbumId,
      releaseDate: albumDetail.releaseDate ?? song.releaseDate,
      language: albumDetail.language ?? song.language,
      description: _buildAlbumDescription(
        title: albumDetail.title.isNotEmpty
            ? albumDetail.title
            : (song.albumTitle ?? 'Album'),
        language: albumDetail.language ?? song.language,
        releaseDate: albumDetail.releaseDate ?? song.releaseDate,
        trackCount: albumDetail.songs.length,
      ),
      externalUrl: albumDetail.permaUrl,
      imageUrl: albumDetail.imageUrl ?? song.imageUrl,
      externalPayload: albumDetail.rawPayload,
      coverBytes: coverBytes,
      coverFilename: coverBytes != null ? '$extAlbumId.jpg' : null,
    );

    for (final artist in albumDetail.artists.skip(1)) {
      if (_isUnknownArtist(artist)) continue;
      final artistId = await _ensureArtist(
        artist,
        contextSummary: _buildAlbumDescription(
          title: albumDetail.title.isNotEmpty
              ? albumDetail.title
              : (song.albumTitle ?? 'Album'),
          language: albumDetail.language ?? song.language,
          releaseDate: albumDetail.releaseDate ?? song.releaseDate,
          trackCount: albumDetail.songs.length,
        ),
      );
      if (artistId == ownerArtistId) continue;
      try {
        await albumsApi.addArtist(
          albumId: createdAlbum.id,
          artistId: artistId,
          role: 'viewer',
        );
      } catch (_) {}
    }

    return createdAlbum.id;
  }

  Future<String> _ensureArtist(
    JioSaavnArtistMeta artist, {
    String? contextSummary,
  }) async {
    if (_isUnknownArtist(artist)) {
      throw Exception('Refusing to create unknown artist');
    }
    final ext = artist.externalId.trim();
    final detail = ext.isEmpty ? null : await _fetchArtistDetailSafe(ext);
    if (ext.isNotEmpty) {
      final existing = await _findExistingByExt(
        table: 'artists',
        idColumn: 'artist_id',
        extColumn: 'ext_artist_id',
        extId: ext,
      );
      if (existing != null) return existing;
    }

    final avatarBytes = await jioApi.downloadImage(
      detail?.imageUrl ?? artist.imageUrl,
    );
    final name = (detail?.name ?? artist.name).trim().isEmpty
        ? 'Unknown Artist'
        : (detail?.name ?? artist.name).trim();
    final safeLocalPart = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    final email =
        '${safeLocalPart.isEmpty ? 'artist' : safeLocalPart}_${ext.isEmpty ? DateTime.now().millisecondsSinceEpoch : ext}@musee.local';

    final created = await _createArtistWithFallback(
      name: name,
      email: email,
      avatarBytes: avatarBytes,
      avatarFilename: avatarBytes != null
          ? '${ext.isEmpty ? name : ext}.jpg'
          : null,
      externalArtistId: ext.isEmpty ? null : ext,
      source: 'jiosaavn',
      externalUrl: detail?.permaUrl,
      imageUrl: detail?.imageUrl ?? artist.imageUrl,
      externalPayload: detail?.rawPayload,
      bio: _buildArtistBio(
        name: name,
        contextSummary: contextSummary,
        preferredBio: detail?.bio,
      ),
    );

    return created.id;
  }

  Future<String?> _findExistingByExt({
    required String table,
    required String idColumn,
    required String extColumn,
    required String extId,
  }) async {
    if (extId.trim().isEmpty) return null;
    try {
      final row = await supabase
          .from(table)
          .select(idColumn)
          .eq(extColumn, extId)
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        return row[idColumn]?.toString();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('findExistingByExt failed: $table.$extColumn=$extId ($e)');
      }
    }
    return null;
  }

  Future<String> _createPlaylist({
    required String externalPlaylistId,
    required String title,
    String? description,
    String? language,
    String? externalUrl,
    String? coverUrl,
    int? trackCount,
    Map<String, dynamic>? externalPayload,
  }) async {
    final coverBytes = await jioApi.downloadImage(coverUrl);
    final resolvedDescription =
        (description != null && description.trim().isNotEmpty)
        ? description.trim()
        : _buildPlaylistDescription(
            title: title,
            language: language,
            trackCount: trackCount,
          );
    final form = dio.FormData();
    form.fields.add(MapEntry('name', title));
    if (resolvedDescription.isNotEmpty) {
      form.fields.add(MapEntry('description', resolvedDescription));
    }
    form.fields.add(const MapEntry('is_public', 'true'));
    form.fields.add(MapEntry('ext_playlist_id', externalPlaylistId));
    form.fields.add(const MapEntry('source', 'jiosaavn'));
    if (externalUrl != null && externalUrl.isNotEmpty) {
      form.fields.add(MapEntry('playlist_url', externalUrl));
      form.fields.add(MapEntry('external_url', externalUrl));
      form.fields.add(MapEntry('perma_url', externalUrl));
    }
    if (coverUrl != null && coverUrl.isNotEmpty) {
      form.fields.add(MapEntry('image', coverUrl));
    }
    if (externalPayload != null && externalPayload.isNotEmpty) {
      form.fields.add(MapEntry('external_payload', jsonEncode(externalPayload)));
    }
    if (language != null && language.trim().isNotEmpty) {
      form.fields.add(MapEntry('genres', '["$language"]'));
    }
    if (coverBytes != null) {
      form.files.add(
        MapEntry(
          'cover',
          dio.MultipartFile.fromBytes(
            coverBytes,
            filename: '$externalPlaylistId.jpg',
          ),
        ),
      );
    }

    dio.Response response;
    try {
      response = await _dio.post(
        '${AppSecrets.backendUrl}/api/admin/playlists',
        data: form,
        options: dio.Options(headers: _authHeader()),
      );
    } on dio.DioException {
      final fallback = dio.FormData();
      fallback.fields.add(MapEntry('name', title));
      if (resolvedDescription.isNotEmpty) {
        fallback.fields.add(MapEntry('description', resolvedDescription));
      }
      fallback.fields.add(const MapEntry('is_public', 'true'));
      fallback.fields.add(const MapEntry('source', 'jiosaavn'));
      fallback.fields.add(MapEntry('ext_playlist_id', externalPlaylistId));
      if (externalUrl != null && externalUrl.isNotEmpty) {
        fallback.fields.add(MapEntry('playlist_url', externalUrl));
        fallback.fields.add(MapEntry('external_url', externalUrl));
        fallback.fields.add(MapEntry('perma_url', externalUrl));
      }
      if (coverUrl != null && coverUrl.isNotEmpty) {
        fallback.fields.add(MapEntry('image', coverUrl));
      }
      if (externalPayload != null && externalPayload.isNotEmpty) {
        fallback.fields.add(MapEntry('external_payload', jsonEncode(externalPayload)));
      }
      if (coverBytes != null) {
        fallback.files.add(
          MapEntry(
            'cover',
            dio.MultipartFile.fromBytes(
              coverBytes,
              filename: '$externalPlaylistId.jpg',
            ),
          ),
        );
      }
      response = await _dio.post(
        '${AppSecrets.backendUrl}/api/admin/playlists',
        data: fallback,
        options: dio.Options(headers: _authHeader()),
      );
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final playlistId =
        data['playlist_id']?.toString() ?? data['id']?.toString();
    if (playlistId == null || playlistId.isEmpty) {
      throw Exception(
        'Playlist creation succeeded but no playlist id returned',
      );
    }
    await _bestEffortUpdateById(
      table: 'playlists',
      idColumn: 'playlist_id',
      idValue: playlistId,
      values: {
        'ext_playlist_id': externalPlaylistId,
        if (language != null && language.trim().isNotEmpty)
          'genres': [language.trim()],
      },
    );
    return playlistId;
  }

  Future<dynamic> _createArtistWithFallback({
    required String name,
    required String email,
    required Uint8List? avatarBytes,
    required String? avatarFilename,
    required String? externalArtistId,
    required String? source,
    required String? externalUrl,
    required String? imageUrl,
    required Map<String, dynamic>? externalPayload,
    required String bio,
  }) async {
    final regionId = await _resolveValidRegionId();

    final existingUserId = await _findUserIdByEmail(email);
    if (existingUserId != null && existingUserId.isNotEmpty) {
      final linked = await _linkArtistToExistingUser(
        userId: existingUserId,
        externalArtistId: externalArtistId,
        regionId: regionId,
        bio: bio,
      );
      if (linked != null) {
        return linked;
      }
    }

    try {
      final created = await artistsApi.createArtist(
        name: name,
        email: email,
        password: 'Temp@123456!',
        bio: bio,
        // Keep payload minimal for multipart to avoid backend array parsing
        // issues (genres must be an actual array on server side).
        avatarBytes: avatarBytes,
        avatarFilename: avatarFilename,
        externalArtistId: externalArtistId,
        source: source,
        externalUrl: externalUrl,
        imageUrl: imageUrl,
        externalPayload: externalPayload,
        regionId: regionId,
      );
      await _bestEffortUpdateById(
        table: 'artists',
        idColumn: 'artist_id',
        idValue: created.id,
        values: {
          if (externalArtistId != null && externalArtistId.isNotEmpty)
            'ext_artist_id': externalArtistId,
        },
      );
      return created;
    } on dio.DioException catch (e) {
      final recoveredUserId = await _findUserIdByEmail(email);
      if (recoveredUserId != null && recoveredUserId.isNotEmpty) {
        final linked = await _linkArtistToExistingUser(
          userId: recoveredUserId,
          externalArtistId: externalArtistId,
          regionId: regionId,
          bio: bio,
        );
        if (linked != null) {
          return linked;
        }
      }

      if (_isEmailExistsError(e)) {
        final emailUserId = await _findUserIdByEmail(email);
        if (emailUserId != null && emailUserId.isNotEmpty) {
          final linked = await _linkArtistToExistingUser(
            userId: emailUserId,
            externalArtistId: externalArtistId,
            regionId: regionId,
            bio: bio,
          );
          if (linked != null) {
            return linked;
          }
        }
        rethrow;
      }

      final created = await artistsApi.createArtist(
        name: name,
        email: email,
        password: 'Temp@123456!',
        bio: bio,
        avatarBytes: avatarBytes,
        avatarFilename: avatarFilename,
        externalArtistId: externalArtistId,
        source: source,
        externalUrl: externalUrl,
        imageUrl: imageUrl,
        externalPayload: externalPayload,
        regionId: regionId,
      );
      await _bestEffortUpdateById(
        table: 'artists',
        idColumn: 'artist_id',
        idValue: created.id,
        values: {
          if (externalArtistId != null && externalArtistId.isNotEmpty)
            'ext_artist_id': externalArtistId,
        },
      );
      return created;
    }
  }

  bool _isUnknownArtist(JioSaavnArtistMeta artist) {
    final name = artist.name.trim().toLowerCase();
    final ext = artist.externalId.trim().toLowerCase();
    if (name.isEmpty || name == 'unknown artist' || name == 'unknown') {
      return true;
    }
    if (ext.isEmpty || ext.startsWith('unknown-') || ext == 'unknown') {
      return true;
    }
    return false;
  }

  JioSaavnArtistMeta? _firstValidArtist(List<JioSaavnArtistMeta> artists) {
    for (final artist in artists) {
      if (!_isUnknownArtist(artist)) {
        return artist;
      }
    }
    return null;
  }

  Future<String?> _findAlbumOwnerArtistId(String albumId) async {
    try {
      final row = await supabase
          .from('albums')
          .select('artist_id')
          .eq('album_id', albumId)
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        return row['artist_id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<dynamic> _linkArtistToExistingUser({
    required String userId,
    required String? externalArtistId,
    required String? regionId,
    required String bio,
  }) async {
    final existingArtist = await _findExistingByExt(
      table: 'artists',
      idColumn: 'artist_id',
      extColumn: 'ext_artist_id',
      extId: externalArtistId ?? '',
    );
    if (existingArtist != null) {
      return artistsApi.getArtist(existingArtist);
    }

    try {
      final created = await artistsApi.createArtist(
        artistId: userId,
        bio: bio,
        externalArtistId: externalArtistId,
        regionId: regionId,
      );
      await _bestEffortUpdateById(
        table: 'artists',
        idColumn: 'artist_id',
        idValue: created.id,
        values: {
          if (externalArtistId != null && externalArtistId.isNotEmpty)
            'ext_artist_id': externalArtistId,
          if (regionId != null && regionId.isNotEmpty) 'region_id': regionId,
        },
      );
      return created;
    } on dio.DioException {
      final already = await _findArtistByUserId(userId);
      if (already != null) {
        await _bestEffortUpdateById(
          table: 'artists',
          idColumn: 'artist_id',
          idValue: already,
          values: {
            if (externalArtistId != null && externalArtistId.isNotEmpty)
              'ext_artist_id': externalArtistId,
            if (regionId != null && regionId.isNotEmpty) 'region_id': regionId,
          },
        );
        return artistsApi.getArtist(already);
      }
      return null;
    }
  }

  Future<String?> _resolveValidRegionId() async {
    if (_cachedValidRegionId != null && _cachedValidRegionId!.isNotEmpty) {
      return _cachedValidRegionId;
    }

    try {
      final response = await _dio.get(
        '${AppSecrets.backendUrl}/api/admin/regions',
        queryParameters: {'page': 0, 'limit': 1},
        options: dio.Options(headers: _authHeader()),
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final items = data['items'];
        if (items is List && items.isNotEmpty) {
          final first = items.first;
          if (first is Map<String, dynamic>) {
            final regionId = first['region_id']?.toString();
            if (regionId != null && regionId.isNotEmpty) {
              _cachedValidRegionId = regionId;
              return regionId;
            }
          }
        }
      }
    } catch (_) {}

    String? userRegionId;
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        final userRow = await supabase
            .from('users')
            .select('region_id')
            .eq('user_id', userId)
            .maybeSingle();
        if (userRow is Map<String, dynamic>) {
          userRegionId = userRow['region_id']?.toString();
        }
      }
    } catch (_) {}

    if (userRegionId != null && userRegionId.isNotEmpty) {
      try {
        final region = await supabase
            .from('regions')
            .select('region_id')
            .eq('region_id', userRegionId)
            .maybeSingle();
        if (region is Map<String, dynamic>) {
          final regionId = region['region_id']?.toString();
          if (regionId != null && regionId.isNotEmpty) {
            return regionId;
          }
        }
      } catch (_) {}
    }

    try {
      final fallback = await supabase
          .from('regions')
          .select('region_id')
          .limit(1)
          .maybeSingle();
      if (fallback is Map<String, dynamic>) {
        final regionId = fallback['region_id']?.toString();
        if (regionId != null && regionId.isNotEmpty) {
          return regionId;
        }
      }
    } catch (_) {}

    return null;
  }

  Future<String?> _findUserIdByEmail(String email) async {
    try {
      final row = await supabase
          .from('users')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        return row['user_id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<String?> _findArtistByUserId(String userId) async {
    try {
      final row = await supabase
          .from('artists')
          .select('artist_id')
          .eq('artist_id', userId)
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        return row['artist_id']?.toString();
      }
    } catch (_) {}
    return null;
  }

  bool _isEmailExistsError(dio.DioException error) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final code = data['code']?.toString().toLowerCase();
      final message = (data['message'] ?? data['error'])
          ?.toString()
          .toLowerCase();
      return code == 'email_exists' ||
          (message?.contains('email') == true && message!.contains('exists'));
    }
    final message = error.message?.toLowerCase() ?? '';
    return message.contains('email_exists');
  }

  Future<dynamic> _createAlbumWithFallback({
    required String title,
    required String artistId,
    required String externalAlbumId,
    required String? releaseDate,
    required String? language,
    required String? description,
    required String? externalUrl,
    required String? imageUrl,
    required Map<String, dynamic>? externalPayload,
    required Uint8List? coverBytes,
    required String? coverFilename,
  }) async {
    try {
      final created = await albumsApi.createAlbum(
        title: title,
        description: description,
        genres: language != null ? [language] : null,
        isPublished: true,
        artistId: artistId,
        coverBytes: coverBytes,
        coverFilename: coverFilename,
        externalAlbumId: externalAlbumId,
        source: 'jiosaavn',
        externalUrl: externalUrl,
        imageUrl: imageUrl,
        externalPayload: externalPayload,
        releaseDate: releaseDate,
        language: language,
      );
      await _bestEffortUpdateById(
        table: 'albums',
        idColumn: 'album_id',
        idValue: created.id,
        values: {
          'ext_album_id': externalAlbumId,
          if (releaseDate != null && releaseDate.isNotEmpty)
            'release_date': releaseDate,
          if (language != null && language.isNotEmpty) 'language': language,
        },
      );
      return created;
    } on dio.DioException {
      final created = await albumsApi.createAlbum(
        title: title,
        description: description,
        genres: language != null ? [language] : null,
        isPublished: true,
        artistId: artistId,
        coverBytes: coverBytes,
        coverFilename: coverFilename,
        externalAlbumId: externalAlbumId,
        source: 'jiosaavn',
        externalUrl: externalUrl,
        imageUrl: imageUrl,
        externalPayload: externalPayload,
        releaseDate: releaseDate,
        language: language,
      );
      await _bestEffortUpdateById(
        table: 'albums',
        idColumn: 'album_id',
        idValue: created.id,
        values: {
          'ext_album_id': externalAlbumId,
          if (releaseDate != null && releaseDate.isNotEmpty)
            'release_date': releaseDate,
          if (language != null && language.isNotEmpty) 'language': language,
        },
      );
      return created;
    }
  }

  Future<dynamic> _createTrackWithFallback({
    required JioSaavnSongDetail song,
    required String albumId,
    required String? externalAlbumId,
    required String? albumImageUrl,
    required Uint8List audioBytes,
    required String audioFilename,
    required List<String> artists,
  }) async {
    final artistPayload = artists
        .map((id) => <String, String>{'artist_id': id, 'role': 'viewer'})
        .toList();

    try {
      final created = await tracksApi.createTrack(
        title: song.title,
        albumId: albumId,
        duration: song.duration > 0 ? song.duration : 180,
        lyricsUrl: null,
        isExplicit: false,
        isPublished: true,
        audioBytes: audioBytes,
        audioFilename: audioFilename,
        artists: artistPayload,
        externalTrackId: song.id,
        source: 'jiosaavn',
        externalUrl: song.permaUrl,
        imageUrl: song.imageUrl ?? albumImageUrl,
        externalAlbumId: externalAlbumId,
        language: song.language,
        releaseDate: song.releaseDate,
        hasLyrics: song.hasLyrics,
        isDrm: song.isDrm,
        isDolbyContent: song.isDolbyContent,
        has320kbps: song.has320kbps,
        encryptedMediaUrl: song.encryptedMediaUrl,
        encryptedDrmMediaUrl: song.encryptedDrmMediaUrl,
        encryptedMediaPath: song.encryptedMediaPath,
        mediaPreviewUrl: song.mediaPreviewUrl,
        rights: song.rights,
        externalPayload: song.rawPayload,
      );
      await _bestEffortUpdateById(
        table: 'tracks',
        idColumn: 'track_id',
        idValue: created.trackId,
        values: {
          'ext_track_id': song.id,
          if (song.language != null && song.language!.isNotEmpty)
            'language': song.language,
          if (song.releaseDate != null && song.releaseDate!.isNotEmpty)
            'release_date': song.releaseDate,
        },
      );
      return created;
    } on dio.DioException {
      final created = await tracksApi.createTrack(
        title: song.title,
        albumId: albumId,
        duration: song.duration > 0 ? song.duration : 180,
        lyricsUrl: null,
        isExplicit: false,
        isPublished: true,
        audioBytes: audioBytes,
        audioFilename: audioFilename,
        artists: artistPayload,
        externalTrackId: song.id,
        source: 'jiosaavn',
        externalUrl: song.permaUrl,
        imageUrl: song.imageUrl ?? albumImageUrl,
        externalAlbumId: externalAlbumId,
        language: song.language,
        releaseDate: song.releaseDate,
        hasLyrics: song.hasLyrics,
        isDrm: song.isDrm,
        isDolbyContent: song.isDolbyContent,
        has320kbps: song.has320kbps,
        encryptedMediaUrl: song.encryptedMediaUrl,
        encryptedDrmMediaUrl: song.encryptedDrmMediaUrl,
        encryptedMediaPath: song.encryptedMediaPath,
        mediaPreviewUrl: song.mediaPreviewUrl,
        rights: song.rights,
        externalPayload: song.rawPayload,
      );
      await _bestEffortUpdateById(
        table: 'tracks',
        idColumn: 'track_id',
        idValue: created.trackId,
        values: {
          'ext_track_id': song.id,
          if (song.language != null && song.language!.isNotEmpty)
            'language': song.language,
          if (song.releaseDate != null && song.releaseDate!.isNotEmpty)
            'release_date': song.releaseDate,
        },
      );
      return created;
    }
  }

  Future<void> _bestEffortUpdateById({
    required String table,
    required String idColumn,
    required String idValue,
    required Map<String, dynamic> values,
  }) async {
    if (values.isEmpty) return;
    try {
      await supabase.from(table).update(values).eq(idColumn, idValue);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('bestEffortUpdate failed for $table/$idValue: $e');
      }
    }
  }

  String _toErrorMessage(Object error, {required String fallback}) {
    if (error is dio.DioException) {
      final status = error.response?.statusCode;
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message =
            data['message']?.toString() ?? data['error']?.toString();
        if (message != null && message.isNotEmpty) {
          return '$fallback ($status): $message';
        }
      }
      return '$fallback${status != null ? ' ($status)' : ''}: ${error.message ?? 'request failed'}';
    }
    return '$fallback: $error';
  }

  Map<String, String> _authHeader() {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing auth token for admin request');
    }
    return {'Authorization': 'Bearer $token'};
  }

  String _buildTrackArtistBio(JioSaavnSongDetail song) {
    final segments = <String>[];
    if (song.title.trim().isNotEmpty) {
      segments.add('Featured on "${song.title.trim()}"');
    }
    if (song.albumTitle != null && song.albumTitle!.trim().isNotEmpty) {
      segments.add('Album: ${song.albumTitle!.trim()}');
    }
    if (song.language != null && song.language!.trim().isNotEmpty) {
      segments.add('Language: ${song.language!.trim()}');
    }
    if (song.releaseDate != null && song.releaseDate!.trim().isNotEmpty) {
      segments.add('Release: ${song.releaseDate!.trim()}');
    }
    return segments.join(' • ');
  }

  String _buildAlbumDescription({
    required String title,
    required String? language,
    required String? releaseDate,
    required int trackCount,
  }) {
    final segments = <String>[];
    if (title.trim().isNotEmpty) {
      segments.add('Album: ${title.trim()}');
    }
    if (trackCount > 0) {
      segments.add('Tracks: $trackCount');
    }
    if (language != null && language.trim().isNotEmpty) {
      segments.add('Language: ${language.trim()}');
    }
    if (releaseDate != null && releaseDate.trim().isNotEmpty) {
      segments.add('Release: ${releaseDate.trim()}');
    }
    return segments.join(' • ');
  }

  String _buildArtistBio({
    required String name,
    String? contextSummary,
    String? preferredBio,
  }) {
    if (preferredBio != null && preferredBio.trim().isNotEmpty) {
      return preferredBio.trim();
    }
    if (contextSummary != null && contextSummary.trim().isNotEmpty) {
      return contextSummary.trim();
    }
    return 'Artist: ${name.trim()}';
  }

  Future<JioSaavnArtistDetail?> _fetchArtistDetailSafe(String externalArtistId) async {
    if (externalArtistId.trim().isEmpty) return null;
    try {
      return await jioApi.getArtistDetails(externalArtistId);
    } catch (_) {
      return null;
    }
  }

  String _buildPlaylistDescription({
    required String title,
    String? language,
    int? trackCount,
  }) {
    final segments = <String>[];
    if (title.trim().isNotEmpty) {
      segments.add('Playlist: ${title.trim()}');
    }
    if (trackCount != null && trackCount > 0) {
      segments.add('Tracks: $trackCount');
    }
    if (language != null && language.trim().isNotEmpty) {
      segments.add('Language: ${language.trim()}');
    }
    return segments.join(' • ');
  }
}
