import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../models/artist_model.dart';

abstract interface class AdminArtistsRemoteDataSource {
  Future<(List<ArtistModel> items, int total, int page, int limit)>
  listArtists({int page, int limit, String? search});

  Future<ArtistModel> getArtist(String id);

  Future<ArtistModel> createArtist({
    String? artistId,
    String? externalArtistId,
    String? name,
    String? email,
    String? password,
    required String bio,
    Uint8List? coverBytes,
    String? coverFilename,
    Uint8List? avatarBytes,
    String? avatarFilename,
    List<String>? genres,
    int? debutYear,
    bool? isVerified,
    Map<String, dynamic>? socialLinks,
    int? monthlyListeners,
    String? regionId,
    DateTime? dateOfBirth,
  });

  Future<ArtistModel> updateArtist({
    required String id,
    String? bio,
    String? coverUrl,
    Uint8List? coverBytes,
    String? coverFilename,
    List<String>? genres,
    int? debutYear,
    bool? isVerified,
    Map<String, dynamic>? socialLinks,
    int? monthlyListeners,
    String? regionId,
    DateTime? dateOfBirth,
  });

  Future<void> deleteArtist(String id);
}

class AdminArtistsRemoteDataSourceImpl implements AdminArtistsRemoteDataSource {
  final dio.Dio _dio;
  final supa.SupabaseClient supabase;
  final String basePath;

  AdminArtistsRemoteDataSourceImpl(this._dio, this.supabase)
    : basePath = '${AppSecrets.backendUrl}/api/admin/artists';

  Map<String, String> _authHeader() {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing Supabase access token for admin API request');
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<(List<ArtistModel> items, int total, int page, int limit)>
  listArtists({int page = 0, int limit = 20, String? search}) async {
    final res = await _dio.get(
      basePath,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
      },
      options: dio.Options(headers: _authHeader()),
    );
    if (kDebugMode) debugPrint('listArtists: ${res.data}');
    final data = res.data as Map<String, dynamic>;
    final list = (data['items'] ?? data['data'] ?? []) as List;
    final items = list
        .map((e) => ArtistModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = (data['total'] ?? items.length) as int;
    final pageNum = (data['page'] ?? page) as int;
    final pageLimit = (data['limit'] ?? limit) as int;
    return (items, total, pageNum, pageLimit);
  }

  String _dateOnly(DateTime dt) => dt.toIso8601String().split('T').first;

  @override
  Future<ArtistModel> getArtist(String id) async {
    final res = await _dio.get(
      '$basePath/$id',
      options: dio.Options(headers: _authHeader()),
    );
    return ArtistModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<ArtistModel> createArtist({
    String? artistId,
    String? externalArtistId,
    String? name,
    String? email,
    String? password,
    required String bio,
    Uint8List? coverBytes,
    String? coverFilename,
    Uint8List? avatarBytes,
    String? avatarFilename,
    List<String>? genres,
    int? debutYear,
    bool? isVerified,
    Map<String, dynamic>? socialLinks,
    int? monthlyListeners,
    String? regionId,
    DateTime? dateOfBirth,
  }) async {
    final form = dio.FormData();
    // Required
    form.fields.add(MapEntry('bio', bio));
    // Option A: link existing user
    if (artistId != null && artistId.isNotEmpty) {
      form.fields.add(MapEntry('artist_id', artistId));
    }
    if (externalArtistId != null && externalArtistId.isNotEmpty) {
      form.fields.add(MapEntry('ext_artist_id', externalArtistId));
    }
    // Option B: create user
    if (name != null) form.fields.add(MapEntry('name', name));
    if (email != null) form.fields.add(MapEntry('email', email));
    if (password != null) form.fields.add(MapEntry('password', password));
    // Optionals
    if (genres != null) form.fields.add(MapEntry('genres', jsonEncode(genres)));
    if (debutYear != null) {
      form.fields.add(MapEntry('debut_year', debutYear.toString()));
    }
    if (isVerified != null) {
      form.fields.add(MapEntry('is_verified', isVerified.toString()));
    }
    if (socialLinks != null) {
      form.fields.add(MapEntry('social_links', jsonEncode(socialLinks)));
    }
    if (monthlyListeners != null) {
      form.fields.add(
        MapEntry('monthly_listeners', monthlyListeners.toString()),
      );
    }
    if (regionId != null) form.fields.add(MapEntry('region_id', regionId));
    if (dateOfBirth != null) {
      form.fields.add(MapEntry('date_of_birth', _dateOnly(dateOfBirth)));
    }
    // Files
    if (coverBytes != null && coverFilename != null) {
      form.files.add(
        MapEntry(
          'cover',
          dio.MultipartFile.fromBytes(coverBytes, filename: coverFilename),
        ),
      );
    }
    if (avatarBytes != null && avatarFilename != null) {
      form.files.add(
        MapEntry(
          'avatar',
          dio.MultipartFile.fromBytes(avatarBytes, filename: avatarFilename),
        ),
      );
    }
    final res = await _dio.post(
      basePath,
      data: form,
      options: dio.Options(headers: _authHeader()),
    );
    return ArtistModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<ArtistModel> updateArtist({
    required String id,
    String? bio,
    String? coverUrl,
    Uint8List? coverBytes,
    String? coverFilename,
    List<String>? genres,
    int? debutYear,
    bool? isVerified,
    Map<String, dynamic>? socialLinks,
    int? monthlyListeners,
    String? regionId,
    DateTime? dateOfBirth,
  }) async {
    final form = dio.FormData();
    if (bio != null) form.fields.add(MapEntry('bio', bio));
    if (coverUrl != null) form.fields.add(MapEntry('cover_url', coverUrl));
    if (genres != null) form.fields.add(MapEntry('genres', jsonEncode(genres)));
    if (debutYear != null) {
      form.fields.add(MapEntry('debut_year', debutYear.toString()));
    }
    if (isVerified != null) {
      form.fields.add(MapEntry('is_verified', isVerified.toString()));
    }
    if (socialLinks != null) {
      form.fields.add(MapEntry('social_links', jsonEncode(socialLinks)));
    }
    if (monthlyListeners != null) {
      form.fields.add(
        MapEntry('monthly_listeners', monthlyListeners.toString()),
      );
    }
    if (regionId != null) form.fields.add(MapEntry('region_id', regionId));
    if (dateOfBirth != null) {
      form.fields.add(MapEntry('date_of_birth', _dateOnly(dateOfBirth)));
    }
    if (coverBytes != null && coverFilename != null) {
      form.files.add(
        MapEntry(
          'cover',
          dio.MultipartFile.fromBytes(coverBytes, filename: coverFilename),
        ),
      );
    }
    final res = await _dio.patch(
      '$basePath/$id',
      data: form,
      options: dio.Options(headers: _authHeader()),
    );
    return ArtistModel.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<void> deleteArtist(String id) async {
    await _dio.delete(
      '$basePath/$id',
      options: dio.Options(headers: _authHeader()),
    );
  }
}
