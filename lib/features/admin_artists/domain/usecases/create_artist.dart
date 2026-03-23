import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import '../entities/artist.dart';
import '../repository/admin_artists_repository.dart';

class CreateArtistParams {
  final String? artistId; // Option A: existing user id
  final String? externalArtistId;
  final String? name; // Option B: create user
  final String? email;
  final String? password;
  final String bio; // required by backend
  final List<int>? coverBytes;
  final String? coverFilename;
  final List<int>? avatarBytes;
  final String? avatarFilename;
  final List<String>? genres;
  final int? debutYear;
  final bool? isVerified;
  final Map<String, dynamic>? socialLinks;
  final int? monthlyListeners;
  final String? regionId;
  final DateTime? dateOfBirth;

  const CreateArtistParams({
    this.artistId,
    this.externalArtistId,
    this.name,
    this.email,
    this.password,
    required this.bio,
    this.coverBytes,
    this.coverFilename,
    this.avatarBytes,
    this.avatarFilename,
    this.genres,
    this.debutYear,
    this.isVerified,
    this.socialLinks,
    this.monthlyListeners,
    this.regionId,
    this.dateOfBirth,
  });
}

class CreateArtist implements UseCase<Artist, CreateArtistParams> {
  final AdminArtistsRepository repo;
  CreateArtist(this.repo);

  @override
  Future<Either<Failure, Artist>> call(CreateArtistParams params) {
    return repo.createArtist(
      artistId: params.artistId,
      externalArtistId: params.externalArtistId,
      name: params.name,
      email: params.email,
      password: params.password,
      bio: params.bio,
      coverBytes: params.coverBytes,
      coverFilename: params.coverFilename,
      avatarBytes: params.avatarBytes,
      avatarFilename: params.avatarFilename,
      genres: params.genres,
      debutYear: params.debutYear,
      isVerified: params.isVerified,
      socialLinks: params.socialLinks,
      monthlyListeners: params.monthlyListeners,
      regionId: params.regionId,
      dateOfBirth: params.dateOfBirth,
    );
  }
}
