import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../entities/onboarding_entities.dart';

abstract class OnboardingRepository {
  /// Get available languages
  Future<Either<Failure, List<Language>>> getAvailableLanguages();

  /// Get available genres
  Future<Either<Failure, List<Genre>>> getAvailableGenres();

  /// Get available moods
  Future<Either<Failure, List<Mood>>> getAvailableMoods();

  /// Search for artists
  Future<Either<Failure, List<Artist>>> searchArtists(String query);

  /// Save user onboarding preferences
  Future<Either<Failure, void>> saveOnboardingPreferences(
    String userId,
    String language,
    List<String> genres,
    List<String> moods,
    List<String> artists,
    int randomness,
  );

  /// Get user's current onboarding preferences
  Future<Either<Failure, OnboardingUser>> getUserOnboardingPreferences(String userId);
}
