import 'dart:convert';
import 'dart:async';

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
  int? _cachedJioProviderId;
  bool _externalRefWritesDisabled = false;
  final Map<String, JioSaavnArtistDetail?> _artistDetailCache = {};

  ({String refTable, String idColumn})? _externalRefConfigForEntity({
    required String table,
    required String extColumn,
  }) {
    final t = table.trim().toLowerCase();
    final c = extColumn.trim().toLowerCase();

    if (t == 'track' || t == 'tracks' || c == 'ext_track_id') {
      return (refTable: 'track_external_refs', idColumn: 'track_id');
    }
    if (t == 'album' || t == 'albums' || c == 'ext_album_id') {
      return (refTable: 'album_external_refs', idColumn: 'album_id');
    }
    if (t == 'artist' || t == 'artists' || c == 'ext_artist_id') {
      return (refTable: 'artist_external_refs', idColumn: 'artist_id');
    }
    if (t == 'playlist' || t == 'playlists' || c == 'ext_playlist_id') {
      return (refTable: 'playlist_external_refs', idColumn: 'playlist_id');
    }
    return null;
  }

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

      final albumCache = <String, JioSaavnAlbumDetail>{};
      final enrichedSongs = <JioSaavnSongDetail>[];
      final artistExternalIds = <String>{};

      for (final song in playlist.songs) {
        final hydratedSong = await _hydrateSongForImport(song);
        final mergedArtists = <JioSaavnArtistMeta>[];
        final dedupeKeys = <String>{};
        JioSaavnSongDetail? albumMatchedSong;

        void addArtist(JioSaavnArtistMeta artist) {
          final ext = artist.externalId.trim();
          final name = artist.name.trim().toLowerCase();
          final key = '${ext.isNotEmpty ? ext : name}::$name';
          if (!dedupeKeys.add(key)) return;
          mergedArtists.add(artist);
          if (ext.isNotEmpty && ext != 'unknown' && !ext.startsWith('unknown-')) {
            artistExternalIds.add(ext);
          }
        }

        for (final artist in hydratedSong.artists) {
          addArtist(artist);
        }

        final albumId = hydratedSong.albumId?.trim();
        if (albumId != null && albumId.isNotEmpty) {
          JioSaavnAlbumDetail? albumDetail = albumCache[albumId];
          if (albumDetail == null) {
            try {
              albumDetail = await jioApi.getAlbumDetails(albumId);
              albumCache[albumId] = albumDetail;
            } catch (_) {
              albumDetail = null;
            }
          }
          if (albumDetail != null) {
            albumMatchedSong = albumDetail.songs
                .where((track) => track.id.trim().isNotEmpty)
                .cast<JioSaavnSongDetail?>()
                .firstWhere(
                  (track) =>
                      track != null &&
                      track.id.trim() == hydratedSong.id.trim(),
                  orElse: () => null,
                );

            albumMatchedSong ??= albumDetail.songs
                .cast<JioSaavnSongDetail?>()
                .firstWhere(
                  (track) =>
                      track != null &&
                      track.title.trim().toLowerCase() ==
                          hydratedSong.title.trim().toLowerCase(),
                  orElse: () => null,
                );

            if (albumMatchedSong != null) {
              for (final artist in albumMatchedSong.artists) {
                addArtist(artist);
              }
            }
            for (final artist in albumDetail.artists) {
              addArtist(artist);
            }

            if (mergedArtists.isEmpty) {
              for (final track in albumDetail.songs) {
                for (final artist in track.artists) {
                  addArtist(artist);
                }
              }
            }
          }
        }

        enrichedSongs.add(
          JioSaavnSongDetail(
            id: hydratedSong.id,
            title: hydratedSong.title,
            albumId: _pickFirstNonEmpty(hydratedSong.albumId, albumMatchedSong?.albumId),
            albumTitle: _pickFirstNonEmpty(
              hydratedSong.albumTitle,
              albumMatchedSong?.albumTitle,
            ),
            imageUrl: _pickFirstNonEmpty(hydratedSong.imageUrl, albumMatchedSong?.imageUrl),
            language: _pickFirstNonEmpty(hydratedSong.language, albumMatchedSong?.language),
            releaseDate: _pickFirstNonEmpty(hydratedSong.releaseDate, albumMatchedSong?.releaseDate),
            duration: hydratedSong.duration > 0
                ? hydratedSong.duration
                : (albumMatchedSong?.duration ?? 0),
            permaUrl: _pickFirstNonEmpty(hydratedSong.permaUrl, albumMatchedSong?.permaUrl),
            hasLyrics: hydratedSong.hasLyrics ?? albumMatchedSong?.hasLyrics,
            isDrm: hydratedSong.isDrm ?? albumMatchedSong?.isDrm,
            isDolbyContent:
                hydratedSong.isDolbyContent ?? albumMatchedSong?.isDolbyContent,
            has320kbps: hydratedSong.has320kbps ?? albumMatchedSong?.has320kbps,
            encryptedDrmMediaUrl: _pickFirstNonEmpty(
              hydratedSong.encryptedDrmMediaUrl,
              albumMatchedSong?.encryptedDrmMediaUrl,
            ),
            encryptedMediaPath: _pickFirstNonEmpty(
              hydratedSong.encryptedMediaPath,
              albumMatchedSong?.encryptedMediaPath,
            ),
            rights: hydratedSong.rights ?? albumMatchedSong?.rights,
            encryptedMediaUrl: _pickFirstNonEmpty(
              hydratedSong.encryptedMediaUrl,
              albumMatchedSong?.encryptedMediaUrl,
            ),
            mediaPreviewUrl: _pickFirstNonEmpty(
              hydratedSong.mediaPreviewUrl,
              albumMatchedSong?.mediaPreviewUrl,
            ),
            artists: mergedArtists,
            rawPayload: {
              ...hydratedSong.rawPayload,
              if (albumMatchedSong != null) ...albumMatchedSong.rawPayload,
            },
          ),
        );
      }

      for (final artistExternalId in artistExternalIds) {
        await _fetchArtistDetailSafe(artistExternalId);
      }

      final importedTrackIds = <String>[];
      for (final song in enrichedSongs) {
        try {
          final result = await _importSongWithRetry(song);
          importedTrackIds.add(result.entityId);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Skipping playlist track ${song.id}/${song.title}: $e');
          }
        }
      }

      if (importedTrackIds.isEmpty) {
        throw Exception(
          'Playlist has no resolvable artist metadata after track, album, and artist API enrichment',
        );
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
    final hydratedSong = await _hydrateSongForImport(song);

    final existingTrack = await _findExistingByExt(
      table: 'tracks',
      idColumn: 'track_id',
      extColumn: 'ext_track_id',
      extId: hydratedSong.id,
    );
    if (existingTrack != null) {
      return ExternalImportResult(
        entityId: existingTrack,
        alreadyExisted: true,
      );
    }

    final albumId = fallbackAlbumId ?? await _ensureAlbumForSong(hydratedSong);
    final artistIds = <String>[];
    for (final artist in hydratedSong.artists) {
      if (_isUnknownArtist(artist)) continue;
      artistIds.add(
        await _ensureArtist(
          artist,
          contextSummary: _buildTrackArtistBio(hydratedSong),
        ),
      );
    }
    if (artistIds.isEmpty) {
      final ownerArtistId = await _findAlbumOwnerArtistId(albumId);
      if (ownerArtistId != null && ownerArtistId.isNotEmpty) {
        artistIds.add(ownerArtistId);
      }
    }
    if (artistIds.isEmpty) {
      throw Exception('Track ${hydratedSong.title} has no valid artist to import');
    }

    final audio = await jioApi.downloadSongAudio(hydratedSong);

    final createdTrack = await _createTrackWithFallback(
      song: hydratedSong,
      albumId: albumId,
      externalAlbumId: hydratedSong.albumId,
      albumImageUrl: hydratedSong.imageUrl,
      audioBytes: audio.$1,
      audioFilename: audio.$2,
      artists: artistIds,
    );

    return ExternalImportResult(entityId: createdTrack.trackId);
  }

  Future<ExternalImportResult> _importSongWithRetry(
    JioSaavnSongDetail song, {
    int maxAttempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _importSong(song);
      } catch (e) {
        lastError = e;
        final canRetry = _isRetryableImportError(e);
        if (!canRetry || attempt == maxAttempts) {
          rethrow;
        }
        final delay = Duration(milliseconds: 400 * attempt);
        await Future.delayed(delay);
      }
    }
    throw Exception(lastError?.toString() ?? 'Unknown import failure');
  }

  bool _isRetryableImportError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('timeoutexception') ||
        message.contains('connection closed') ||
        message.contains('connection terminated') ||
        message.contains('handshakeexception') ||
        message.contains('socketexception') ||
        message.contains('failed host lookup') ||
        message.contains('future not completed');
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
      _firstValidArtist(song.artists) ??
      _firstValidArtist(
        albumDetail.songs
          .expand((track) => track.artists)
          .toList(),
      );
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

    final resolvedName = _pickFirstNonEmpty(detail?.name, artist.name);
    if (resolvedName == null || resolvedName.trim().isEmpty) {
      throw Exception('Refusing to create unknown artist');
    }

    final avatarBytes = await jioApi.downloadImage(
      _pickFirstNonEmpty(detail?.imageUrl, artist.imageUrl),
    );
    final name = resolvedName.trim();
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
      externalUrl: _pickFirstNonEmpty(detail?.permaUrl, null),
      imageUrl: _pickFirstNonEmpty(detail?.imageUrl, artist.imageUrl),
      externalPayload: detail?.rawPayload,
      bio: _buildArtistBio(
        name: name,
        contextSummary: contextSummary,
        preferredBio: _pickFirstNonEmpty(detail?.bio, null),
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
      final providerId = await _resolveJioProviderId();
      final config = _externalRefConfigForEntity(table: table, extColumn: extColumn);
      if (config != null) {

        final row = await supabase
            .from(config.refTable)
            .select(config.idColumn)
            .eq('provider_id', providerId)
            .eq('external_id', extId)
            .maybeSingle();

        if (row is Map<String, dynamic>) {
          return row[config.idColumn]?.toString();
        }
        return null;
      }

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

  Future<int> _resolveJioProviderId() async {
    if (_cachedJioProviderId != null) {
      return _cachedJioProviderId!;
    }

    try {
      final row = await supabase
          .from('external_providers')
          .select('provider_id')
          .eq('code', 'jiosaavn')
          .maybeSingle();
      if (row is Map<String, dynamic>) {
        final id = (row['provider_id'] as num?)?.toInt();
        if (id != null) {
          _cachedJioProviderId = id;
          return id;
        }
      }
    } catch (_) {}

    _cachedJioProviderId = 1;
    return _cachedJioProviderId!;
  }

  Future<void> _upsertExternalRef({
    required String entityTable,
    required String entityId,
    required String externalId,
    String? externalUrl,
    String? imageUrl,
    Map<String, dynamic>? rawPayload,
    Map<String, dynamic>? extra,
  }) async {
    if (externalId.trim().isEmpty) return;
    if (_externalRefWritesDisabled) return;

    final providerId = await _resolveJioProviderId();
    final config = _externalRefConfigForEntity(table: entityTable, extColumn: '');
    if (config == null) return;

    final payload = <String, dynamic>{
      config.idColumn: entityId,
      'provider_id': providerId,
      'external_id': externalId,
      if (externalUrl != null && externalUrl.isNotEmpty) 'external_url': externalUrl,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
      if (rawPayload != null && rawPayload.isNotEmpty) 'raw_payload': rawPayload,
      ...?extra,
    };

    try {
      await supabase
          .from(config.refTable)
          .upsert(payload, onConflict: 'provider_id,external_id');
    } catch (e) {
      final msg = e.toString().toLowerCase();
      final isRlsDenied = msg.contains('42501') ||
          msg.contains('code: 42501') ||
          msg.contains('row-level security') ||
          msg.contains('violates row-level security policy') ||
          msg.contains('forbidden');
      if (isRlsDenied) {
        _externalRefWritesDisabled = true;
        if (kDebugMode) {
          debugPrint(
            'external ref writes disabled due to RLS for this session (${config.refTable})',
          );
        }
        return;
      }
      if (kDebugMode) {
        debugPrint('upsertExternalRef failed for ${config.refTable}/$externalId: $e');
      }
    }
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
    final safeTitle = title.trim().isNotEmpty
        ? title.trim()
        : 'Playlist $externalPlaylistId';
    final coverBytes = await jioApi.downloadImage(coverUrl);
    final resolvedDescription =
        (description != null && description.trim().isNotEmpty)
        ? description.trim()
        : _buildPlaylistDescription(
            title: safeTitle,
            language: language,
            trackCount: trackCount,
          );
    final form = dio.FormData();
    form.fields.add(MapEntry('name', safeTitle));
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
      fallback.fields.add(MapEntry('name', safeTitle));
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
        if (language != null && language.trim().isNotEmpty)
          'genres': [language.trim()],
      },
    );
    await _upsertExternalRef(
      entityTable: 'playlists',
      entityId: playlistId,
      externalId: externalPlaylistId,
      externalUrl: externalUrl,
      imageUrl: coverUrl,
      rawPayload: externalPayload,
    );
    return playlistId;
  }

  Future<JioSaavnSongDetail> _hydrateSongForImport(
    JioSaavnSongDetail song,
  ) async {
    if (song.id.trim().isEmpty) return song;
    try {
      final detail = await jioApi.getSongDetails(song.id);
      return JioSaavnSongDetail(
        id: detail.id,
        title: detail.title.isNotEmpty ? detail.title : song.title,
        albumId: detail.albumId ?? song.albumId,
        albumTitle: detail.albumTitle ?? song.albumTitle,
        imageUrl: detail.imageUrl ?? song.imageUrl,
        language: detail.language ?? song.language,
        releaseDate: detail.releaseDate ?? song.releaseDate,
        duration: detail.duration > 0 ? detail.duration : song.duration,
        permaUrl: detail.permaUrl ?? song.permaUrl,
        hasLyrics: detail.hasLyrics ?? song.hasLyrics,
        isDrm: detail.isDrm ?? song.isDrm,
        isDolbyContent: detail.isDolbyContent ?? song.isDolbyContent,
        has320kbps: detail.has320kbps ?? song.has320kbps,
        encryptedDrmMediaUrl: detail.encryptedDrmMediaUrl ?? song.encryptedDrmMediaUrl,
        encryptedMediaPath: detail.encryptedMediaPath ?? song.encryptedMediaPath,
        rights: detail.rights ?? song.rights,
        encryptedMediaUrl: detail.encryptedMediaUrl ?? song.encryptedMediaUrl,
        mediaPreviewUrl: detail.mediaPreviewUrl ?? song.mediaPreviewUrl,
        artists: detail.artists.isNotEmpty ? detail.artists : song.artists,
        rawPayload: detail.rawPayload.isNotEmpty ? detail.rawPayload : song.rawPayload,
      );
    } catch (_) {
      return song;
    }
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
        values: const {},
      );
      if (externalArtistId != null && externalArtistId.isNotEmpty) {
        await _upsertExternalRef(
          entityTable: 'artists',
          entityId: created.id,
          externalId: externalArtistId,
          externalUrl: externalUrl,
          imageUrl: imageUrl,
          rawPayload: externalPayload,
        );
      }
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
        values: const {},
      );
      if (externalArtistId != null && externalArtistId.isNotEmpty) {
        await _upsertExternalRef(
          entityTable: 'artists',
          entityId: created.id,
          externalId: externalArtistId,
          externalUrl: externalUrl,
          imageUrl: imageUrl,
          rawPayload: externalPayload,
        );
      }
      return created;
    }
  }

  bool _isUnknownArtist(JioSaavnArtistMeta artist) {
    final name = artist.name.trim().toLowerCase();
    final ext = artist.externalId.trim().toLowerCase();
    final invalidName =
        name.isEmpty || name == 'unknown artist' || name == 'unknown';
    final invalidExternalId =
        ext.isEmpty || ext.startsWith('unknown-') || ext == 'unknown';
    return invalidName && invalidExternalId;
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
          if (regionId != null && regionId.isNotEmpty) 'region_id': regionId,
        },
      );
      if (externalArtistId != null && externalArtistId.isNotEmpty) {
        await _upsertExternalRef(
          entityTable: 'artists',
          entityId: created.id,
          externalId: externalArtistId,
        );
      }
      return created;
    } on dio.DioException {
      final already = await _findArtistByUserId(userId);
      if (already != null) {
        await _bestEffortUpdateById(
          table: 'artists',
          idColumn: 'artist_id',
          idValue: already,
          values: {
            if (regionId != null && regionId.isNotEmpty) 'region_id': regionId,
          },
        );
        if (externalArtistId != null && externalArtistId.isNotEmpty) {
          await _upsertExternalRef(
            entityTable: 'artists',
            entityId: already,
            externalId: externalArtistId,
          );
        }
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
          if (releaseDate != null && releaseDate.isNotEmpty)
            'release_date': releaseDate,
        },
      );
      await _upsertExternalRef(
        entityTable: 'albums',
        entityId: created.id,
        externalId: externalAlbumId,
        externalUrl: externalUrl,
        imageUrl: imageUrl,
        rawPayload: externalPayload,
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
          if (releaseDate != null && releaseDate.isNotEmpty)
            'release_date': releaseDate,
        },
      );
      await _upsertExternalRef(
        entityTable: 'albums',
        entityId: created.id,
        externalId: externalAlbumId,
        externalUrl: externalUrl,
        imageUrl: imageUrl,
        rawPayload: externalPayload,
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
        values: const {},
      );
      await _upsertExternalRef(
        entityTable: 'tracks',
        entityId: created.trackId,
        externalId: song.id,
        externalUrl: song.permaUrl,
        imageUrl: song.imageUrl ?? albumImageUrl,
        rawPayload: song.rawPayload,
        extra: {
          if (externalAlbumId != null && externalAlbumId.isNotEmpty)
            'external_album_id': externalAlbumId,
          if (song.language != null && song.language!.isNotEmpty)
            'language': song.language,
          if (song.releaseDate != null && song.releaseDate!.isNotEmpty)
            'release_date': song.releaseDate,
          if (song.hasLyrics != null) 'has_lyrics': song.hasLyrics,
          if (song.isDrm != null) 'is_drm': song.isDrm,
          if (song.isDolbyContent != null)
            'is_dolby_content': song.isDolbyContent,
          if (song.has320kbps != null) 'has_320kbps': song.has320kbps,
          if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty)
            'encrypted_media_url': song.encryptedMediaUrl,
          if (song.encryptedDrmMediaUrl != null &&
              song.encryptedDrmMediaUrl!.isNotEmpty)
            'encrypted_drm_media_url': song.encryptedDrmMediaUrl,
          if (song.encryptedMediaPath != null &&
              song.encryptedMediaPath!.isNotEmpty)
            'encrypted_media_path': song.encryptedMediaPath,
          if (song.mediaPreviewUrl != null && song.mediaPreviewUrl!.isNotEmpty)
            'media_preview_url': song.mediaPreviewUrl,
          if (song.rights != null) 'rights': song.rights,
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
        values: const {},
      );
      await _upsertExternalRef(
        entityTable: 'tracks',
        entityId: created.trackId,
        externalId: song.id,
        externalUrl: song.permaUrl,
        imageUrl: song.imageUrl ?? albumImageUrl,
        rawPayload: song.rawPayload,
        extra: {
          if (externalAlbumId != null && externalAlbumId.isNotEmpty)
            'external_album_id': externalAlbumId,
          if (song.language != null && song.language!.isNotEmpty)
            'language': song.language,
          if (song.releaseDate != null && song.releaseDate!.isNotEmpty)
            'release_date': song.releaseDate,
          if (song.hasLyrics != null) 'has_lyrics': song.hasLyrics,
          if (song.isDrm != null) 'is_drm': song.isDrm,
          if (song.isDolbyContent != null)
            'is_dolby_content': song.isDolbyContent,
          if (song.has320kbps != null) 'has_320kbps': song.has320kbps,
          if (song.encryptedMediaUrl != null && song.encryptedMediaUrl!.isNotEmpty)
            'encrypted_media_url': song.encryptedMediaUrl,
          if (song.encryptedDrmMediaUrl != null &&
              song.encryptedDrmMediaUrl!.isNotEmpty)
            'encrypted_drm_media_url': song.encryptedDrmMediaUrl,
          if (song.encryptedMediaPath != null &&
              song.encryptedMediaPath!.isNotEmpty)
            'encrypted_media_path': song.encryptedMediaPath,
          if (song.mediaPreviewUrl != null && song.mediaPreviewUrl!.isNotEmpty)
            'media_preview_url': song.mediaPreviewUrl,
          if (song.rights != null) 'rights': song.rights,
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
    if (_artistDetailCache.containsKey(externalArtistId)) {
      return _artistDetailCache[externalArtistId];
    }
    try {
      final detail = await jioApi.getArtistDetails(externalArtistId);
      _artistDetailCache[externalArtistId] = detail;
      return detail;
    } catch (_) {
      _artistDetailCache[externalArtistId] = null;
      return null;
    }
  }

  String? _pickFirstNonEmpty(String? preferred, String? fallback) {
    if (preferred != null && preferred.trim().isNotEmpty) return preferred;
    if (fallback != null && fallback.trim().isNotEmpty) return fallback;
    return null;
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
