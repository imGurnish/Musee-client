import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/track_model.dart';

abstract interface class AdminTracksRemoteDataSource {
  Future<(List<TrackModel>, int total, int page, int limit)> listTracks({
    int page = 0,
    int limit = 20,
    String? q,
  });

  Future<TrackModel> getTrack(String id);

  Future<TrackModel> createTrack({
    required String title,
    required String albumId,
    required int duration,
    String? externalTrackId,
    String? language,
    String? releaseDate,
    String? lyricsUrl,
    bool? isExplicit,
    bool? isPublished,
    required Uint8List audioBytes,
    required String audioFilename,
    Uint8List? videoBytes,
    String? videoFilename,
    List<Map<String, String>>? artists,
  });

  Future<TrackModel> updateTrack({
    required String id,
    String? title,
    String? albumId,
    int? duration,
    String? externalTrackId,
    String? language,
    String? releaseDate,
    String? lyricsUrl,
    bool? isExplicit,
    bool? isPublished,
    Uint8List? audioBytes,
    String? audioFilename,
    Uint8List? videoBytes,
    String? videoFilename,
    List<Map<String, String>>? artists,
  });

  Future<void> deleteTrack(String id);

  // Artist management
  Future<void> linkArtistToTrack({
    required String trackId,
    required String artistId,
    required String role,
  });

  Future<void> updateTrackArtistRole({
    required String trackId,
    required String artistId,
    required String role,
  });

  Future<void> unlinkArtistFromTrack({
    required String trackId,
    required String artistId,
  });
}

class AdminTracksRemoteDataSourceImpl implements AdminTracksRemoteDataSource {
  final dio.Dio _dio;
  final supa.SupabaseClient supabase;
  final String basePath;

  AdminTracksRemoteDataSourceImpl(this._dio, this.supabase)
    : basePath = '${AppSecrets.backendUrl}/api/admin/tracks';

  Map<String, String> _authHeader() {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing Supabase access token for admin API request');
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<(List<TrackModel>, int total, int page, int limit)> listTracks({
    int page = 0,
    int limit = 20,
    String? q,
  }) async {
    final res = await _dio.get(
      basePath,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      },
      options: dio.Options(headers: _authHeader()),
    );
    if (kDebugMode) debugPrint('listTracks: ${res.data}');
    final data = res.data as Map<String, dynamic>;
    final list = (data['items'] ?? data['data'] ?? []) as List;
    final items = list
        .map((e) => TrackModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = (data['total'] ?? items.length) as int;
    final pageNum = (data['page'] ?? page) as int;
    final pageLimit = (data['limit'] ?? limit) as int;
    return (items, total, pageNum, pageLimit);
  }

  @override
  Future<TrackModel> getTrack(String id) async {
    final res = await _dio.get(
      '$basePath/$id',
      options: dio.Options(headers: _authHeader()),
    );
    return TrackModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<TrackModel> createTrack({
    required String title,
    required String albumId,
    required int duration,
    String? externalTrackId,
    String? language,
    String? releaseDate,
    String? lyricsUrl,
    bool? isExplicit,
    bool? isPublished,
    required Uint8List audioBytes,
    required String audioFilename,
    Uint8List? videoBytes,
    String? videoFilename,
    List<Map<String, String>>? artists,
  }) async {
    // Audio is required for create per API; always multipart
    final form = dio.FormData();
    form.fields.add(MapEntry('title', title));
    form.fields.add(MapEntry('album_id', albumId));
    form.fields.add(MapEntry('duration', duration.toString()));
    if (externalTrackId != null && externalTrackId.isNotEmpty) {
      form.fields.add(MapEntry('ext_track_id', externalTrackId));
    }
    if (language != null && language.isNotEmpty) {
      form.fields.add(MapEntry('language', language));
    }
    if (releaseDate != null && releaseDate.isNotEmpty) {
      form.fields.add(MapEntry('release_date', releaseDate));
    }
    if (lyricsUrl != null) form.fields.add(MapEntry('lyrics_url', lyricsUrl));
    if (isExplicit != null) {
      form.fields.add(MapEntry('is_explicit', isExplicit.toString()));
    }
    if (isPublished != null) {
      form.fields.add(MapEntry('is_published', isPublished.toString()));
    }
    if (artists != null && artists.isNotEmpty) {
      form.fields.add(MapEntry('artists', jsonEncode(artists)));
    }

    form.files.add(
      MapEntry(
        'audio',
        dio.MultipartFile.fromBytes(audioBytes, filename: audioFilename),
      ),
    );
    if (videoBytes != null && videoFilename != null) {
      form.files.add(
        MapEntry(
          'video',
          dio.MultipartFile.fromBytes(videoBytes, filename: videoFilename),
        ),
      );
    }

    final res = await _dio.post(
      basePath,
      data: form,
      options: dio.Options(headers: _authHeader()),
    );
    return TrackModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<TrackModel> updateTrack({
    required String id,
    String? title,
    String? albumId,
    int? duration,
    String? externalTrackId,
    String? language,
    String? releaseDate,
    String? lyricsUrl,
    bool? isExplicit,
    bool? isPublished,
    Uint8List? audioBytes,
    String? audioFilename,
    Uint8List? videoBytes,
    String? videoFilename,
    List<Map<String, String>>? artists,
  }) async {
    final isMultipart = audioBytes != null || videoBytes != null;
    if (isMultipart) {
      final form = dio.FormData();
      if (title != null) form.fields.add(MapEntry('title', title));
      if (albumId != null) form.fields.add(MapEntry('album_id', albumId));
      if (duration != null) {
        form.fields.add(MapEntry('duration', duration.toString()));
      }
      if (externalTrackId != null && externalTrackId.isNotEmpty) {
        form.fields.add(MapEntry('ext_track_id', externalTrackId));
      }
      if (language != null && language.isNotEmpty) {
        form.fields.add(MapEntry('language', language));
      }
      if (releaseDate != null && releaseDate.isNotEmpty) {
        form.fields.add(MapEntry('release_date', releaseDate));
      }
      if (lyricsUrl != null) form.fields.add(MapEntry('lyrics_url', lyricsUrl));
      if (isExplicit != null) {
        form.fields.add(MapEntry('is_explicit', isExplicit.toString()));
      }
      if (isPublished != null) {
        form.fields.add(MapEntry('is_published', isPublished.toString()));
      }
      if (artists != null && artists.isNotEmpty) {
        form.fields.add(MapEntry('artists', jsonEncode(artists)));
      }

      if (audioBytes != null && audioFilename != null) {
        form.files.add(
          MapEntry(
            'audio',
            dio.MultipartFile.fromBytes(audioBytes, filename: audioFilename),
          ),
        );
      }
      if (videoBytes != null && videoFilename != null) {
        form.files.add(
          MapEntry(
            'video',
            dio.MultipartFile.fromBytes(videoBytes, filename: videoFilename),
          ),
        );
      }

      final res = await _dio.patch(
        '$basePath/$id',
        data: form,
        options: dio.Options(headers: _authHeader()),
      );
      return TrackModel.fromJson(Map<String, dynamic>.from(res.data));
    } else {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (albumId != null) body['album_id'] = albumId;
      if (duration != null) body['duration'] = duration;
      if (externalTrackId != null && externalTrackId.isNotEmpty) {
        body['ext_track_id'] = externalTrackId;
      }
      if (language != null && language.isNotEmpty) body['language'] = language;
      if (releaseDate != null && releaseDate.isNotEmpty) {
        body['release_date'] = releaseDate;
      }
      if (lyricsUrl != null) body['lyrics_url'] = lyricsUrl;
      if (isExplicit != null) body['is_explicit'] = isExplicit;
      if (isPublished != null) body['is_published'] = isPublished;
      if (artists != null && artists.isNotEmpty) body['artists'] = artists;

      final res = await _dio.patch(
        '$basePath/$id',
        data: body,
        options: dio.Options(headers: _authHeader()),
      );
      return TrackModel.fromJson(Map<String, dynamic>.from(res.data));
    }
  }

  @override
  Future<void> deleteTrack(String id) async {
    await _dio.delete(
      '$basePath/$id',
      options: dio.Options(headers: _authHeader()),
    );
  }

  @override
  Future<void> linkArtistToTrack({
    required String trackId,
    required String artistId,
    required String role,
  }) async {
    await _dio.post(
      '$basePath/$trackId/artists',
      data: {'artist_id': artistId, 'role': role},
      options: dio.Options(headers: _authHeader()),
    );
  }

  @override
  Future<void> updateTrackArtistRole({
    required String trackId,
    required String artistId,
    required String role,
  }) async {
    await _dio.patch(
      '$basePath/$trackId/artists/$artistId',
      data: {'role': role},
      options: dio.Options(headers: _authHeader()),
    );
  }

  @override
  Future<void> unlinkArtistFromTrack({
    required String trackId,
    required String artistId,
  }) async {
    await _dio.delete(
      '$basePath/$trackId/artists/$artistId',
      options: dio.Options(headers: _authHeader()),
    );
  }
}
