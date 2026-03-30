import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import '../entities/album.dart';

abstract interface class AdminAlbumsRepository {
  Future<Either<Failure, (List<Album> items, int total, int page, int limit)>>
  listAlbums({int page, int limit, String? q});
  Future<Either<Failure, Album>> getAlbum(String id);
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
  });
  Future<Either<Failure, Album>> updateAlbum({
    required String id,
    String? title,
    String? description,
    List<String>? genres,
    bool? isPublished,
    List<int>? coverBytes,
    String? coverFilename,
  });
  Future<Either<Failure, void>> deleteAlbum(String id);
  Future<Either<Failure, void>> deleteAlbums(List<String> ids);

  Future<Either<Failure, Map<String, dynamic>>> addArtist({
    required String albumId,
    required String artistId,
    String? role,
  });
  Future<Either<Failure, Map<String, dynamic>>> updateArtistRole({
    required String albumId,
    required String artistId,
    required String role,
  });
  Future<Either<Failure, void>> removeArtist({
    required String albumId,
    required String artistId,
  });
}
