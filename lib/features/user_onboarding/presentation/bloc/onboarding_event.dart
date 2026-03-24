part of 'onboarding_bloc.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize onboarding - fetch all available options
class InitializeOnboardingEvent extends OnboardingEvent {
  const InitializeOnboardingEvent();
}

/// Select a genre (toggle)
class SelectGenreEvent extends OnboardingEvent {
  final String genreId;

  const SelectGenreEvent(this.genreId);

  @override
  List<Object?> get props => [genreId];
}

/// Select a mood (toggle)
class SelectMoodEvent extends OnboardingEvent {
  final String moodId;

  const SelectMoodEvent(this.moodId);

  @override
  List<Object?> get props => [moodId];
}

/// Select a language
class SelectLanguageEvent extends OnboardingEvent {
  final String languageCode;

  const SelectLanguageEvent(this.languageCode);

  @override
  List<Object?> get props => [languageCode];
}

/// Search artists by query
class SearchArtistsEvent extends OnboardingEvent {
  final String query;

  const SearchArtistsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

/// Select an artist from search results
class SelectArtistEvent extends OnboardingEvent {
  final ArtistSearchModel artist;

  const SelectArtistEvent(this.artist);

  @override
  List<Object?> get props => [artist];
}

/// Remove a selected artist
class RemoveSelectedArtistEvent extends OnboardingEvent {
  final String artistId;

  const RemoveSelectedArtistEvent(this.artistId);

  @override
  List<Object?> get props => [artistId];
}

/// Update randomness percentage
class UpdateRandomnessEvent extends OnboardingEvent {
  final int percentage;

  const UpdateRandomnessEvent(this.percentage);

  @override
  List<Object?> get props => [percentage];
}

/// Save all preferences
class SavePreferencesEvent extends OnboardingEvent {
  final String userId;

  const SavePreferencesEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Fetch existing user preferences
class FetchUserPreferencesEvent extends OnboardingEvent {
  final String userId;

  const FetchUserPreferencesEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}
