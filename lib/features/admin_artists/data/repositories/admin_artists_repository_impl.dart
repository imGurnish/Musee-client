import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/features/admin_artists/data/datasources/admin_artists_remote_data_source.dart';
import 'package:musee/features/admin_artists/domain/entities/artist.dart';
import 'package:musee/features/admin_artists/domain/repository/admin_artists_repository.dart';

class AdminArtistsRepositoryImpl implements AdminArtistsRepository {
  final AdminArtistsRemoteDataSource remote;

  AdminArtistsRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, (List<Artist> items, int total, int page, int limit)>>
  listArtists({int page = 0, int limit = 20, String? search}) async {
    try {
      final r = await remote.listArtists(
        page: page,
        limit: limit,
        search: search,
      );
      return right((r.$1, r.$2, r.$3, r.$4));
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Artist>> getArtist(String id) async {
    try {
      final a = await remote.getArtist(id);
      return right(a);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Artist>> createArtist({
    String? artistId,
    String? externalArtistId,
    String? name,
    String? email,
    required String bio,
    List<int>? coverBytes,
    String? coverFilename,
    List<int>? avatarBytes,
    String? avatarFilename,
    List<String>? genres,
    int? debutYear,
    bool? isVerified,
    Map<String, dynamic>? socialLinks,
    int? monthlyListeners,
    String? regionId,
    DateTime? dateOfBirth,
  }) async {
    try {
      final a = await remote.createArtist(
        artistId: artistId,
        externalArtistId: externalArtistId,
        name: name,
        email: email,
        bio: bio,
        coverBytes: coverBytes != null ? Uint8List.fromList(coverBytes) : null,
        coverFilename: coverFilename,
        avatarBytes: avatarBytes != null
            ? Uint8List.fromList(avatarBytes)
            : null,
        avatarFilename: avatarFilename,
        genres: genres,
        debutYear: debutYear,
        isVerified: isVerified,
        socialLinks: socialLinks,
        monthlyListeners: monthlyListeners,
        regionId: regionId,
        dateOfBirth: dateOfBirth,
      );
      return right(a);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Artist>> updateArtist({
    required String id,
    String? bio,
    String? coverUrl,
    List<int>? coverBytes,
    String? coverFilename,
    List<String>? genres,
    int? debutYear,
    bool? isVerified,
    Map<String, dynamic>? socialLinks,
    int? monthlyListeners,
    String? regionId,
    DateTime? dateOfBirth,
  }) async {
    try {
      final a = await remote.updateArtist(
        id: id,
        bio: bio,
        coverUrl: coverUrl,
        coverBytes: coverBytes != null ? Uint8List.fromList(coverBytes) : null,
        coverFilename: coverFilename,
        genres: genres,
        debutYear: debutYear,
        isVerified: isVerified,
        socialLinks: socialLinks,
        monthlyListeners: monthlyListeners,
        regionId: regionId,
        dateOfBirth: dateOfBirth,
      );
      return right(a);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteArtist(String id) async {
    try {
      await remote.deleteArtist(id);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteArtists(List<String> ids) async {
    try {
      await remote.deleteArtists(ids);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }
}
