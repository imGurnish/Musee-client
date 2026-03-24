import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../domain/entities/onboarding_entities.dart';
import '../../domain/repository/onboarding_repository.dart';

// Get Available Languages
class GetAvailableLanguagesUseCase
    implements UseCase<List<Language>, NoParams> {
  final OnboardingRepository repository;

  GetAvailableLanguagesUseCase(this.repository);

  @override
  Future<Either<Failure, List<Language>>> call(NoParams params) async {
    return await repository.getAvailableLanguages();
  }
}

// Get Available Genres
class GetAvailableGenresUseCase implements UseCase<List<Genre>, NoParams> {
  final OnboardingRepository repository;

  GetAvailableGenresUseCase(this.repository);

  @override
  Future<Either<Failure, List<Genre>>> call(NoParams params) async {
    return await repository.getAvailableGenres();
  }
}

// Get Available Moods
class GetAvailableMoodsUseCase implements UseCase<List<Mood>, NoParams> {
  final OnboardingRepository repository;

  GetAvailableMoodsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Mood>>> call(NoParams params) async {
    return await repository.getAvailableMoods();
  }
}

// Search Artists
class SearchArtistsUseCase implements UseCase<List<Artist>, String> {
  final OnboardingRepository repository;

  SearchArtistsUseCase(this.repository);

  @override
  Future<Either<Failure, List<Artist>>> call(String query) async {
    return await repository.searchArtists(query);
  }
}

// Save Onboarding Preferences
class SaveOnboardingPreferencesUseCase
    implements UseCase<void, SaveOnboardingPreferencesParams> {
  final OnboardingRepository repository;

  SaveOnboardingPreferencesUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SaveOnboardingPreferencesParams params) async {
    return await repository.saveOnboardingPreferences(
      params.userId,
      params.language,
      params.genres,
      params.moods,
      params.artists,
      params.randomness,
    );
  }
}

class SaveOnboardingPreferencesParams {
  final String userId;
  final String language;
  final List<String> genres;
  final List<String> moods;
  final List<String> artists;
  final int randomness;

  SaveOnboardingPreferencesParams({
    required this.userId,
    required this.language,
    required this.genres,
    required this.moods,
    required this.artists,
    required this.randomness,
  });
}

// Get User Onboarding Preferences
class GetUserOnboardingPreferencesUseCase
    implements UseCase<OnboardingUser, String> {
  final OnboardingRepository repository;

  GetUserOnboardingPreferencesUseCase(this.repository);

  @override
  Future<Either<Failure, OnboardingUser>> call(String userId) async {
    return await repository.getUserOnboardingPreferences(userId);
  }
}
