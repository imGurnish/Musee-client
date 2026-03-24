import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/models/onboarding_models.dart';
import '../../domain/usecases/onboarding_usecases.dart';
import '../../../../core/usecase/usecase.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final GetAvailableLanguagesUseCase getAvailableLanguagesUseCase;
  final GetAvailableGenresUseCase getAvailableGenresUseCase;
  final GetAvailableMoodsUseCase getAvailableMoodsUseCase;
  final SearchArtistsUseCase searchArtistsUseCase;
  final SaveOnboardingPreferencesUseCase saveOnboardingPreferencesUseCase;
  final GetUserOnboardingPreferencesUseCase getUserOnboardingPreferencesUseCase;

  OnboardingBloc({
    required this.getAvailableLanguagesUseCase,
    required this.getAvailableGenresUseCase,
    required this.getAvailableMoodsUseCase,
    required this.searchArtistsUseCase,
    required this.saveOnboardingPreferencesUseCase,
    required this.getUserOnboardingPreferencesUseCase,
  }) : super(const OnboardingState.initial()) {
    on<InitializeOnboardingEvent>(_onInitializeOnboarding);
    on<SelectGenreEvent>(_onSelectGenre);
    on<SelectMoodEvent>(_onSelectMood);
    on<SelectLanguageEvent>(_onSelectLanguage);
    on<SearchArtistsEvent>(_onSearchArtists);
    on<SelectArtistEvent>(_onSelectArtist);
    on<RemoveSelectedArtistEvent>(_onRemoveSelectedArtist);
    on<UpdateRandomnessEvent>(_onUpdateRandomness);
    on<SavePreferencesEvent>(_onSavePreferences);
    on<FetchUserPreferencesEvent>(_onFetchUserPreferences);
  }

  Future<void> _onInitializeOnboarding(
    InitializeOnboardingEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // Fetch all data in parallel
      final languagesResult = await getAvailableLanguagesUseCase.call(NoParams());
      final genresResult = await getAvailableGenresUseCase.call(NoParams());
      final moodsResult = await getAvailableMoodsUseCase.call(NoParams());

      languagesResult.fold(
        (failure) => emit(state.copyWith(
          isLoading: false,
          error: failure.message,
        )),
        (languages) {
          genresResult.fold(
            (failure) => emit(state.copyWith(
              isLoading: false,
              error: failure.message,
            )),
            (genres) {
              moodsResult.fold(
                (failure) => emit(state.copyWith(
                  isLoading: false,
                  error: failure.message,
                )),
                (moods) {
                  final languageModels = languages
                      .map((l) => LanguageModel(
                            code: l.code,
                            name: l.name,
                            nativeName: l.nativeName,
                            isSelected: l.code == 'en', // Default to English
                          ))
                      .toList();

                  final genreModels = genres
                      .map((g) => GenreModel(
                            id: g.id,
                            name: g.name,
                            icon: g.icon,
                          ))
                      .toList();

                  final moodModels = moods
                      .map((m) => MoodModel(
                            id: m.id,
                            name: m.name,
                            icon: m.icon,
                            description: m.description,
                          ))
                      .toList();

                  emit(state.copyWith(
                    isLoading: false,
                    languages: languageModels,
                    genres: genreModels,
                    moods: moodModels,
                    selectedLanguage: languageModels.first,
                  ));
                },
              );
            },
          );
        },
      );
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: 'Failed to initialize onboarding: $e',
      ));
    }
  }

  Future<void> _onSelectGenre(
    SelectGenreEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    final updatedGenres = state.genres.map((genre) {
      if (genre.id == event.genreId) {
        return genre.copyWith(isSelected: !genre.isSelected);
      }
      return genre;
    }).toList();

    final selectedGenreIds = updatedGenres
        .where((g) => g.isSelected)
        .map((g) => g.id)
        .toList();

    emit(state.copyWith(
      genres: updatedGenres,
      selectedGenres: selectedGenreIds,
    ));
  }

  Future<void> _onSelectMood(
    SelectMoodEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    final updatedMoods = state.moods.map((mood) {
      if (mood.id == event.moodId) {
        return mood.copyWith(isSelected: !mood.isSelected);
      }
      return mood;
    }).toList();

    final selectedMoodIds = updatedMoods
        .where((m) => m.isSelected)
        .map((m) => m.id)
        .toList();

    emit(state.copyWith(
      moods: updatedMoods,
      selectedMoods: selectedMoodIds,
    ));
  }

  Future<void> _onSelectLanguage(
    SelectLanguageEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    final updatedLanguages = state.languages.map((lang) {
      return lang.copyWith(isSelected: lang.code == event.languageCode);
    }).toList();

    final selectedLanguage = updatedLanguages
        .firstWhere((l) => l.code == event.languageCode);

    emit(state.copyWith(
      languages: updatedLanguages,
      selectedLanguage: selectedLanguage,
    ));
  }

  Future<void> _onSearchArtists(
    SearchArtistsEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isSearching: true));

    final result = await searchArtistsUseCase.call(event.query);

    result.fold(
      (failure) => emit(state.copyWith(
        isSearching: false,
        searchError: failure.message,
      )),
      (artists) {
        final artistModels = artists
            .map((a) => ArtistSearchModel(
                  id: a.id,
                  name: a.name,
                  imageUrl: a.imageUrl,
                  genre: a.genre,
                ))
            .toList();

        emit(state.copyWith(
          isSearching: false,
          searchResults: artistModels,
        ));
      },
    );
  }

  Future<void> _onSelectArtist(
    SelectArtistEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    if (!state.selectedArtists.any((a) => a.id == event.artist.id)) {
      final updatedArtists = [...state.selectedArtists, event.artist];
      emit(state.copyWith(selectedArtists: updatedArtists));
    }
  }

  Future<void> _onRemoveSelectedArtist(
    RemoveSelectedArtistEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    final updatedArtists = state.selectedArtists
        .where((a) => a.id != event.artistId)
        .toList();

    emit(state.copyWith(selectedArtists: updatedArtists));
  }

  Future<void> _onUpdateRandomness(
    UpdateRandomnessEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(randomnessPercentage: event.percentage));
  }

  Future<void> _onSavePreferences(
    SavePreferencesEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isSaving: true));

    final params = SaveOnboardingPreferencesParams(
      userId: event.userId,
      language: state.selectedLanguage?.code ?? 'en',
      genres: state.selectedGenres,
      moods: state.selectedMoods,
      artists: state.selectedArtists.map((a) => a.id).toList(),
      randomness: state.randomnessPercentage,
    );

    final result = await saveOnboardingPreferencesUseCase.call(params);

    result.fold(
      (failure) => emit(state.copyWith(
        isSaving: false,
        error: failure.message,
      )),
      (_) => emit(state.copyWith(
        isSaving: false,
        isCompleted: true,
      )),
    );
  }

  Future<void> _onFetchUserPreferences(
    FetchUserPreferencesEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    final result = await getUserOnboardingPreferencesUseCase.call(event.userId);

    result.fold(
      (failure) => emit(state.copyWith(
        isLoading: false,
        error: failure.message,
      )),
      (preferences) {
        // Map preferences back to UI models

        emit(state.copyWith(
          isLoading: false,
          selectedGenres: preferences.favoriteGenres,
          selectedMoods: preferences.favoriteMoods,
          randomnessPercentage: preferences.randomnessPercentage,
          genres: state.genres.map((g) {
            return g.copyWith(
              isSelected: preferences.favoriteGenres.contains(g.id),
            );
          }).toList(),
          moods: state.moods.map((m) {
            return m.copyWith(
              isSelected: preferences.favoriteMoods.contains(m.id),
            );
          }).toList(),
        ));
      },
    );
  }
}
