import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import '../models/album_model.dart';

abstract interface class AdminAlbumsRemoteDataSource {
  Future<(List<AlbumModel> items, int total, int page, int limit)> listAlbums({
    int page,
    int limit,
    String? q,
  });
  Future<AlbumModel> getAlbum(String id);
  Future<AlbumModel> createAlbum({
    required String title,
    String? description,
    List<String>? genres,
    bool? isPublished,
    required String artistId,
    String? externalAlbumId,
    String? source,
    String? externalUrl,
    String? imageUrl,
    Map<String, dynamic>? externalPayload,
    String? releaseDate,
    String? language,
    Uint8List? coverBytes,
    String? coverFilename,
  });
  Future<AlbumModel> updateAlbum({
    required String id,
    String? title,
    String? description,
    List<String>? genres,
    bool? isPublished,
    Uint8List? coverBytes,
    String? coverFilename,
  });
  Future<void> deleteAlbum(String id);

  Future<Map<String, dynamic>> addArtist({
    required String albumId,
    required String artistId,
    String? role,
  });
  Future<Map<String, dynamic>> updateArtistRole({
    required String albumId,
    required String artistId,
    required String role,
  });
  Future<void> removeArtist({
    required String albumId,
    required String artistId,
  });
}

class AdminAlbumsRemoteDataSourceImpl implements AdminAlbumsRemoteDataSource {
  final dio.Dio _dio;
  final supa.SupabaseClient supabase;
  final String basePath;

  AdminAlbumsRemoteDataSourceImpl(this._dio, this.supabase)
    : basePath = '${AppSecrets.backendUrl}/api/admin/albums';

  Map<String, String> _authHeader() {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing Supabase access token for admin API request');
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<(List<AlbumModel> items, int total, int page, int limit)> listAlbums({
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
    if (kDebugMode) debugPrint('listAlbums: ${res.data}');
    final data = res.data as Map<String, dynamic>;
    final list = (data['items'] ?? data['data'] ?? []) as List;
    final items = list
        .map((e) => AlbumModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = (data['total'] ?? items.length) as int;
    final pageNum = (data['page'] ?? page) as int;
    final pageLimit = (data['limit'] ?? limit) as int;
    return (items, total, pageNum, pageLimit);
  }

  @override
  Future<AlbumModel> getAlbum(String id) async {
    final res = await _dio.get(
      '$basePath/$id',
      options: dio.Options(headers: _authHeader()),
    );
    return AlbumModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<AlbumModel> createAlbum({
    required String title,
    String? description,
    List<String>? genres,
    bool? isPublished,
    required String artistId,
    String? externalAlbumId,
    String? source,
    String? externalUrl,
    String? imageUrl,
    Map<String, dynamic>? externalPayload,
    String? releaseDate,
    String? language,
    Uint8List? coverBytes,
    String? coverFilename,
  }) async {
    final isMultipart = coverBytes != null && coverFilename != null;
    if (isMultipart) {
      final form = dio.FormData();
      form.fields.add(MapEntry('title', title));
      form.fields.add(MapEntry('artist_id', artistId));
      if (externalAlbumId != null && externalAlbumId.isNotEmpty) {
        form.fields.add(MapEntry('ext_album_id', externalAlbumId));
      }
      if (source != null && source.isNotEmpty) {
        form.fields.add(MapEntry('source', source));
      }
      if (externalUrl != null && externalUrl.isNotEmpty) {
        form.fields.add(MapEntry('album_url', externalUrl));
        form.fields.add(MapEntry('external_url', externalUrl));
        form.fields.add(MapEntry('perma_url', externalUrl));
      }
      if (imageUrl != null && imageUrl.isNotEmpty) {
        form.fields.add(MapEntry('image', imageUrl));
      }
      if (externalPayload != null && externalPayload.isNotEmpty) {
        form.fields.add(MapEntry('external_payload', jsonEncode(externalPayload)));
      }
      if (description != null) {
        form.fields.add(MapEntry('description', description));
      }
      if (isPublished != null) {
        form.fields.add(MapEntry('is_published', isPublished.toString()));
      }
      if (releaseDate != null && releaseDate.isNotEmpty) {
        form.fields.add(MapEntry('release_date', releaseDate));
      }
      if (language != null && language.isNotEmpty) {
        form.fields.add(MapEntry('language_code', language));
      }
      form.files.add(
        MapEntry(
          'cover',
          dio.MultipartFile.fromBytes(coverBytes, filename: coverFilename),
        ),
      );
      final res = await _dio.post(
        basePath,
        data: form,
        options: dio.Options(headers: _authHeader()),
      );
      return AlbumModel.fromJson(Map<String, dynamic>.from(res.data));
    } else {
      final body = {
        'title': title,
        if (externalAlbumId != null && externalAlbumId.isNotEmpty)
          'ext_album_id': externalAlbumId,
        if (source != null && source.isNotEmpty) 'source': source,
        if (externalUrl != null && externalUrl.isNotEmpty)
          'album_url': externalUrl,
        if (externalUrl != null && externalUrl.isNotEmpty)
          'external_url': externalUrl,
        if (externalUrl != null && externalUrl.isNotEmpty)
          'perma_url': externalUrl,
        if (imageUrl != null && imageUrl.isNotEmpty) 'image': imageUrl,
        if (externalPayload != null && externalPayload.isNotEmpty)
          'external_payload': externalPayload,
        if (description != null) 'description': description,
        if (isPublished != null) 'is_published': isPublished,
        if (releaseDate != null && releaseDate.isNotEmpty)
          'release_date': releaseDate,
        if (language != null && language.isNotEmpty) 'language_code': language,
        'artist_id': artistId,
      };
      final res = await _dio.post(
        basePath,
        data: body,
        options: dio.Options(headers: _authHeader()),
      );
      return AlbumModel.fromJson(Map<String, dynamic>.from(res.data));
    }
  }

  @override
  Future<AlbumModel> updateAlbum({
    required String id,
    String? title,
    String? description,
    List<String>? genres,
    bool? isPublished,
    Uint8List? coverBytes,
    String? coverFilename,
  }) async {
    final isMultipart = coverBytes != null && coverFilename != null;
    if (isMultipart) {
      final form = dio.FormData();
      if (title != null) form.fields.add(MapEntry('title', title));
      if (description != null) {
        form.fields.add(MapEntry('description', description));
      }
      if (isPublished != null) {
        form.fields.add(MapEntry('is_published', isPublished.toString()));
      }
      form.files.add(
        MapEntry(
          'cover',
          dio.MultipartFile.fromBytes(coverBytes, filename: coverFilename),
        ),
      );
      final res = await _dio.patch(
        '$basePath/$id',
        data: form,
        options: dio.Options(headers: _authHeader()),
      );
      return AlbumModel.fromJson(Map<String, dynamic>.from(res.data));
    } else {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (isPublished != null) body['is_published'] = isPublished;
      final res = await _dio.patch(
        '$basePath/$id',
        data: body,
        options: dio.Options(headers: _authHeader()),
      );
      return AlbumModel.fromJson(Map<String, dynamic>.from(res.data));
    }
  }

  @override
  Future<void> deleteAlbum(String id) async {
    await _dio.delete(
      '$basePath/$id',
      options: dio.Options(headers: _authHeader()),
    );
  }

  @override
  Future<Map<String, dynamic>> addArtist({
    required String albumId,
    required String artistId,
    String? role,
  }) async {
    final res = await _dio.post(
      '$basePath/$albumId/artists',
      data: {'artist_id': artistId, if (role != null) 'role': role},
      options: dio.Options(headers: _authHeader()),
    );
    return Map<String, dynamic>.from(res.data);
  }

  @override
  Future<Map<String, dynamic>> updateArtistRole({
    required String albumId,
    required String artistId,
    required String role,
  }) async {
    final res = await _dio.patch(
      '$basePath/$albumId/artists/$artistId',
      data: {'role': role},
      options: dio.Options(headers: _authHeader()),
    );
    return Map<String, dynamic>.from(res.data);
  }

  @override
  Future<void> removeArtist({
    required String albumId,
    required String artistId,
  }) async {
    await _dio.delete(
      '$basePath/$albumId/artists/$artistId',
      options: dio.Options(headers: _authHeader()),
    );
  }
}
