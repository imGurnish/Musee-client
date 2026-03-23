import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import '../entities/album.dart';
import '../repository/admin_albums_repository.dart';

class CreateAlbumParams {
  final String title;
  final String? description;
  final List<String>? genres;
  final bool? isPublished;
  final String artistId;
  final String? externalAlbumId;
  final String? releaseDate;
  final String? language;
  final List<int>? coverBytes;
  final String? coverFilename;

  const CreateAlbumParams({
    required this.title,
    this.description,
    this.genres,
    this.isPublished,
    required this.artistId,
    this.externalAlbumId,
    this.releaseDate,
    this.language,
    this.coverBytes,
    this.coverFilename,
  });
}

class CreateAlbum implements UseCase<Album, CreateAlbumParams> {
  final AdminAlbumsRepository repo;
  CreateAlbum(this.repo);

  @override
  Future<Either<Failure, Album>> call(CreateAlbumParams params) {
    return repo.createAlbum(
      title: params.title,
      description: params.description,
      genres: params.genres,
      isPublished: params.isPublished,
      artistId: params.artistId,
      externalAlbumId: params.externalAlbumId,
      releaseDate: params.releaseDate,
      language: params.language,
      coverBytes: params.coverBytes,
      coverFilename: params.coverFilename,
    );
  }
}
