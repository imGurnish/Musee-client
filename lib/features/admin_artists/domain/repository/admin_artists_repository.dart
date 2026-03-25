import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import '../entities/artist.dart';

abstract interface class AdminArtistsRepository {
  Future<Either<Failure, (List<Artist> items, int total, int page, int limit)>>
  listArtists({int page, int limit, String? search});

  Future<Either<Failure, Artist>> getArtist(String id);

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
  });

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
  });

  Future<Either<Failure, void>> deleteArtist(String id);

  Future<Either<Failure, void>> deleteArtists(List<String> ids);
}
