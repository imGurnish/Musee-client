import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../data/datasources/onboarding_remote_data_source.dart';
import '../../data/models/onboarding_models.dart';
import '../../domain/entities/onboarding_entities.dart';
import '../../domain/repository/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  final OnboardingRemoteDataSource remoteDataSource;

  OnboardingRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<Language>>> getAvailableLanguages() async {
    try {
      final languages = await remoteDataSource.getAvailableLanguages();
      return Right(_mapLanguageModelToEntity(languages));
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Genre>>> getAvailableGenres() async {
    try {
      final genres = await remoteDataSource.getAvailableGenres();
      return Right(_mapGenreModelToEntity(genres));
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Mood>>> getAvailableMoods() async {
    try {
      final moods = await remoteDataSource.getAvailableMoods();
      return Right(_mapMoodModelToEntity(moods));
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Artist>>> searchArtists(String query) async {
    try {
      final artists = await remoteDataSource.searchArtists(query);
      return Right(_mapArtistModelToEntity(artists));
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveOnboardingPreferences(
    String userId,
    String language,
    List<String> genres,
    List<String> moods,
    List<String> artists,
    int randomness,
  ) async {
    try {
      final dto = OnboardingUserDTO(
        userId: userId,
        preferredLanguage: language,
        favoriteGenres: genres,
        favoriteMoods: moods,
        favoriteArtists: artists,
        randomnessPercentage: randomness,
      );
      await remoteDataSource.saveOnboardingPreferences(dto);
      return const Right(null);
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, OnboardingUser>> getUserOnboardingPreferences(
    String userId,
  ) async {
    try {
      final dto = await remoteDataSource.getUserOnboardingPreferences(userId);
      final entity = OnboardingUser(
        userId: dto.userId,
        preferredLanguage: dto.preferredLanguage,
        favoriteGenres: dto.favoriteGenres,
        favoriteMoods: dto.favoriteMoods,
        favoriteArtists: dto.favoriteArtists,
        randomnessPercentage: dto.randomnessPercentage,
      );
      return Right(entity);
    } catch (e) {
      return Left(Failure(e.toString()));
    }
  }

  // Mapping functions
  List<Language> _mapLanguageModelToEntity(List<LanguageModel> models) {
    return models.map((model) {
      return Language(
        code: model.code,
        name: model.name,
        nativeName: model.nativeName,
      );
    }).toList();
  }

  List<Genre> _mapGenreModelToEntity(List<GenreModel> models) {
    return models.map((model) {
      return Genre(
        id: model.id,
        name: model.name,
        icon: model.icon,
      );
    }).toList();
  }

  List<Mood> _mapMoodModelToEntity(List<MoodModel> models) {
    return models.map((model) {
      return Mood(
        id: model.id,
        name: model.name,
        icon: model.icon,
        description: model.description,
      );
    }).toList();
  }

  List<Artist> _mapArtistModelToEntity(List<ArtistSearchModel> models) {
    return models.map((model) {
      return Artist(
        id: model.id,
        name: model.name,
        imageUrl: model.imageUrl,
        genre: model.genre,
      );
    }).toList();
  }
}
