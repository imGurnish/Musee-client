import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/features/admin_albums/data/datasources/admin_albums_remote_data_source.dart';
import 'package:musee/features/admin_albums/domain/entities/album.dart';
import 'package:musee/features/admin_albums/domain/repository/admin_albums_repository.dart';

class AdminAlbumsRepositoryImpl implements AdminAlbumsRepository {
  final AdminAlbumsRemoteDataSource remote;
  AdminAlbumsRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, (List<Album> items, int total, int page, int limit)>>
  listAlbums({int page = 0, int limit = 20, String? q}) async {
    try {
      final r = await remote.listAlbums(page: page, limit: limit, q: q);
      return right((r.$1, r.$2, r.$3, r.$4));
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Album>> getAlbum(String id) async {
    try {
      final a = await remote.getAlbum(id);
      return right(a);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Album>> createAlbum({
    required String title,
    String? description,
    List<String>? genres,
    bool? isPublished,
    required String artistId,
    String? externalAlbumId,
    String? releaseDate,
    String? language,
    List<int>? coverBytes,
    String? coverFilename,
  }) async {
    try {
      final a = await remote.createAlbum(
        title: title,
        description: description,
        genres: genres,
        isPublished: isPublished,
        artistId: artistId,
        externalAlbumId: externalAlbumId,
        releaseDate: releaseDate,
        language: language,
        coverBytes: coverBytes != null ? Uint8List.fromList(coverBytes) : null,
        coverFilename: coverFilename,
      );
      return right(a);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Album>> updateAlbum({
    required String id,
    String? title,
    String? description,
    List<String>? genres,
    bool? isPublished,
    List<int>? coverBytes,
    String? coverFilename,
  }) async {
    try {
      final a = await remote.updateAlbum(
        id: id,
        title: title,
        description: description,
        genres: genres,
        isPublished: isPublished,
        coverBytes: coverBytes != null ? Uint8List.fromList(coverBytes) : null,
        coverFilename: coverFilename,
      );
      return right(a);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAlbum(String id) async {
    try {
      await remote.deleteAlbum(id);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> addArtist({
    required String albumId,
    required String artistId,
    String? role,
  }) async {
    try {
      final r = await remote.addArtist(
        albumId: albumId,
        artistId: artistId,
        role: role,
      );
      return right(r);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> updateArtistRole({
    required String albumId,
    required String artistId,
    required String role,
  }) async {
    try {
      final r = await remote.updateArtistRole(
        albumId: albumId,
        artistId: artistId,
        role: role,
      );
      return right(r);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> removeArtist({
    required String albumId,
    required String artistId,
  }) async {
    try {
      await remote.removeArtist(albumId: albumId, artistId: artistId);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }
}
