import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

abstract interface class AdminRemoteDataSource {
  Future<(List<User> items, int total, int page, int limit)> listUsers({
    int page,
    int limit,
    String? search,
  });

  Future<User> getUser(String id);

  Future<User> createUser({
    required String name,
    required String email,
    SubscriptionType subscriptionType,
    String? planId,
    Uint8List? avatarBytes,
    String? avatarFilename,
  });

  Future<User> updateUser({
    required String id,
    String? name,
    String? email,
    SubscriptionType? subscriptionType,
    String? planId,
    Uint8List? avatarBytes,
    String? avatarFilename,
  });

  Future<void> deleteUser(String id);

  Future<void> deleteUsers(List<String> ids);
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  final dio.Dio _dio;
  final supa.SupabaseClient supabase;
  final String basePath;

  AdminRemoteDataSourceImpl(this._dio, this.supabase)
    : basePath = '${AppSecrets.backendUrl}/api/admin/users';

  Map<String, String> _authHeader() {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing Supabase access token for admin API request');
    }
    return {'Authorization': 'Bearer $token'};
  }

  @override
  Future<(List<User> items, int total, int page, int limit)> listUsers({
    int page = 0,
    int limit = 20,
    String? search,
  }) async {
    final res = await _dio.get(
      basePath,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
      },
      options: dio.Options(headers: _authHeader()),
    );
    if (kDebugMode) {
      debugPrint('AdminRemoteDataSourceImpl.listUsers response: ${res.data}');
    }
    final data = res.data;
    final list = (data['items'] ?? data['data'] ?? []) as List;
    final items = list
        .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final total = (data['total'] ?? items.length) as int;
    final pageNum = (data['page'] ?? page) as int;
    final pageLimit = (data['limit'] ?? limit) as int;
    return (items, total, pageNum, pageLimit);
  }

  @override
  Future<User> getUser(String id) async {
    final res = await _dio.get(
      '$basePath/$id',
      options: dio.Options(headers: _authHeader()),
    );
    return User.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<User> createUser({
    required String name,
    required String email,
    SubscriptionType subscriptionType = SubscriptionType.free,
    String? planId,
    Uint8List? avatarBytes,
    String? avatarFilename,
  }) async {
    final formData = dio.FormData();
    formData.fields
      ..add(MapEntry('name', name))
      ..add(MapEntry('email', email))
      ..add(MapEntry('subscription_type', subscriptionType.value));
    if (planId != null) formData.fields.add(MapEntry('plan_id', planId));
    if (avatarBytes != null && avatarFilename != null) {
      formData.files.add(
        MapEntry(
          'avatar',
          dio.MultipartFile.fromBytes(avatarBytes, filename: avatarFilename),
        ),
      );
    }

    final res = await _dio.post(
      basePath,
      data: formData,
      options: dio.Options(headers: _authHeader()),
    );
    return User.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<User> updateUser({
    required String id,
    String? name,
    String? email,
    SubscriptionType? subscriptionType,
    String? planId,
    Uint8List? avatarBytes,
    String? avatarFilename,
  }) async {
    final formData = dio.FormData();
    if (name != null) formData.fields.add(MapEntry('name', name));
    if (email != null) formData.fields.add(MapEntry('email', email));
    if (subscriptionType != null) {
      formData.fields.add(
        MapEntry('subscription_type', subscriptionType.value),
      );
    }
    if (planId != null) formData.fields.add(MapEntry('plan_id', planId));
    if (avatarBytes != null && avatarFilename != null) {
      formData.files.add(
        MapEntry(
          'avatar',
          dio.MultipartFile.fromBytes(avatarBytes, filename: avatarFilename),
        ),
      );
    }

    final res = await _dio.patch(
      '$basePath/$id',
      data: formData,
      options: dio.Options(headers: _authHeader()),
    );
    return User.fromJson(Map<String, dynamic>.from(res.data));
  }

  @override
  Future<void> deleteUser(String id) async {
    await _dio.delete(
      '$basePath/$id',
      options: dio.Options(headers: _authHeader()),
    );
  }

  @override
  Future<void> deleteUsers(List<String> ids) async {
    if (ids.isEmpty) return;
    await _dio.post(
      '$basePath/bulk-delete',
      data: {'ids': ids},
      options: dio.Options(headers: _authHeader()),
    );
  }
}
