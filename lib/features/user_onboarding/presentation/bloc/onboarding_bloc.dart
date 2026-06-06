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
  final GetSimilarArtistsUseCase getSimilarArtistsUseCase;
  final SaveOnboardingPreferencesUseCase saveOnboardingPreferencesUseCase;
  final GetUserOnboardingPreferencesUseCase getUserOnboardingPreferencesUseCase;

  OnboardingBloc({
    required this.getAvailableLanguagesUseCase,
    required this.getAvailableGenresUseCase,
    required this.getAvailableMoodsUseCase,
    required this.searchArtistsUseCase,
    required this.getSimilarArtistsUseCase,
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
      final languagesResult = await getAvailableLanguagesUseCase.call(
        NoParams(),
      );
      final genresResult = await getAvailableGenresUseCase.call(NoParams());
      final moodsResult = await getAvailableMoodsUseCase.call(NoParams());

      languagesResult.fold(
        (failure) =>
            emit(state.copyWith(isLoading: false, error: failure.message)),
        (languages) {
          genresResult.fold(
            (failure) =>
                emit(state.copyWith(isLoading: false, error: failure.message)),
            (genres) {
              moodsResult.fold(
                (failure) => emit(
                  state.copyWith(isLoading: false, error: failure.message),
                ),
                (moods) {
                  final languageModels = languages
                      .map(
                        (l) => LanguageModel(
                          code: l.code,
                          name: l.name,
                          nativeName: l.nativeName,
                          isSelected: l.code == 'en', // Default to English
                        ),
                      )
                      .toList();

                  final genreModels = genres
                      .map(
                        (g) => GenreModel(id: g.id, name: g.name, icon: g.icon),
                      )
                      .toList();

                  final moodModels = moods
                      .map(
                        (m) => MoodModel(
                          id: m.id,
                          name: m.name,
                          icon: m.icon,
                          description: m.description,
                        ),
                      )
                      .toList();

                  emit(
                    state.copyWith(
                      isLoading: false,
                      languages: languageModels,
                      genres: genreModels,
                      moods: moodModels,
                      selectedLanguages: languageModels
                          .where((language) => language.isSelected)
                          .toList(),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Failed to initialize onboarding: $e',
        ),
      );
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

    emit(
      state.copyWith(genres: updatedGenres, selectedGenres: selectedGenreIds),
    );
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

    emit(state.copyWith(moods: updatedMoods, selectedMoods: selectedMoodIds));
  }

  Future<void> _onSelectLanguage(
    SelectLanguageEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    final updatedLanguages = state.languages.map((lang) {
      if (lang.code == event.languageCode) {
        return lang.copyWith(isSelected: !lang.isSelected);
      }
      return lang;
    }).toList();

    final selectedLanguages = updatedLanguages
        .where((language) => language.isSelected)
        .toList();

    emit(
      state.copyWith(
        languages: updatedLanguages,
        selectedLanguages: selectedLanguages,
      ),
    );
  }

  Future<void> _onSearchArtists(
    SearchArtistsEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isSearching: true));

    final selectedLanguageCodes = state.selectedLanguages
        .map((lang) => lang.code)
        .toList();

    final result = await searchArtistsUseCase.call(
      SearchArtistsParams(
        query: event.query,
        languages: selectedLanguageCodes,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(isSearching: false, searchError: failure.message),
      ),
      (artists) {
        final artistModels = artists
            .map(
              (a) => ArtistSearchModel(
                id: a.id,
                name: a.name,
                imageUrl: a.imageUrl,
                genre: a.genre,
              ),
            )
            .toList();

        emit(state.copyWith(isSearching: false, searchResults: artistModels));
      },
    );
  }

  Future<void> _onSelectArtist(
    SelectArtistEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    print('ONBOARDING_BLOC: _onSelectArtist called for artist: ${event.artist.name} (ID: ${event.artist.id})');
    if (!state.selectedArtists.any((a) => a.id == event.artist.id)) {
      final updatedArtists = [...state.selectedArtists, event.artist];
      emit(state.copyWith(selectedArtists: updatedArtists));

      // If the list of visible artists is already above 100, stop adding and show notification
      if (state.searchResults.length > 100) {
        print('ONBOARDING_BLOC: Search results list count (${state.searchResults.length}) is already > 100. Stopping similar artists fetch.');
        emit(state.copyWith(error: 'Too many artists selected'));
        // Reset the error immediately so subsequent state emissions do not re-trigger the snackbar
        emit(state.copyWith(error: ''));
        return;
      }

      print('ONBOARDING_BLOC: Fetching similar artists for artist ID: ${event.artist.id}');
      // Fetch similar artists in real time
      final result = await getSimilarArtistsUseCase.call(event.artist.id);
      result.fold(
        (failure) {
          print('ONBOARDING_BLOC: Fetching similar artists failed: ${failure.message}');
          // Ignore similar artists fetch errors during onboarding to avoid blocking signup
        },
        (similarArtists) {
          print('ONBOARDING_BLOC: Fetched ${similarArtists.length} similar artists: ${similarArtists.map((a) => a.name).toList()}');
          if (similarArtists.isEmpty) {
            print('ONBOARDING_BLOC: No similar artists returned by database');
            return;
          }

          final selectedIds = updatedArtists.map((a) => a.id).toSet();
          final existingIds = state.searchResults.map((a) => a.id).toSet();

          // ONLY select similar artists that are NOT selected AND NOT already visible in the list
          final targetSimilar = similarArtists
              .where((a) => !selectedIds.contains(a.id) && !existingIds.contains(a.id))
              .take(3)
              .toList();

          print('ONBOARDING_BLOC: Selected ${targetSimilar.length} new unseen similar artists: ${targetSimilar.map((a) => a.name).toList()}');

          if (targetSimilar.isEmpty) {
            print('ONBOARDING_BLOC: No new unseen similar artists to insert');
            return;
          }

          // Duplicate state's search results exactly as they are without removing anything
          final newSearchResults = [...state.searchResults];

          // Find where the selected artist is in the list
          final index = newSearchResults.indexWhere((a) => a.id == event.artist.id);
          
          if (index != -1) {
            int insertOffset = 1;
            for (final similar in targetSimilar) {
              final model = ArtistSearchModel(
                id: similar.id,
                name: similar.name,
                imageUrl: similar.imageUrl,
                genre: similar.genre,
              );
              print('ONBOARDING_BLOC: Inserting new unseen similar artist ${similar.name} at index ${index + insertOffset}');
              newSearchResults.insert(index + insertOffset, model);
              insertOffset++;
            }
          } else {
            // Fallback: just append
            for (final similar in targetSimilar) {
              print('ONBOARDING_BLOC: Appending new unseen similar artist ${similar.name}');
              newSearchResults.add(ArtistSearchModel(
                id: similar.id,
                name: similar.name,
                imageUrl: similar.imageUrl,
                genre: similar.genre,
              ));
            }
          }

          print('ONBOARDING_BLOC: Emitting state with updated searchResults count: ${newSearchResults.length}');
          emit(state.copyWith(searchResults: newSearchResults));
        },
      );
    } else {
      print('ONBOARDING_BLOC: Artist ${event.artist.name} is already selected, doing nothing');
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

    final selectedLanguageCodes = state.selectedLanguages.isNotEmpty
        ? state.selectedLanguages.map((language) => language.code).toList()
        : <String>['en'];

    final params = SaveOnboardingPreferencesParams(
      userId: event.userId,
      languages: selectedLanguageCodes,
      genres: state.selectedGenres,
      moods: state.selectedMoods,
      artists: state.selectedArtists.map((a) => a.id).toList(),
      randomness: state.randomnessPercentage,
    );

    final result = await saveOnboardingPreferencesUseCase.call(params);

    result.fold(
      (failure) =>
          emit(state.copyWith(isSaving: false, error: failure.message)),
      (_) => emit(state.copyWith(isSaving: false, isCompleted: true)),
    );
  }

  Future<void> _onFetchUserPreferences(
    FetchUserPreferencesEvent event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    final result = await getUserOnboardingPreferencesUseCase.call(event.userId);

    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (preferences) {
        // Map preferences back to UI models
        final selectedLanguageCodes = preferences.preferredLanguages.toSet();

        emit(
          state.copyWith(
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
            selectedLanguages: state.languages.map((language) {
              return language.copyWith(
                isSelected: selectedLanguageCodes.contains(language.code),
              );
            }).toList(),
            languages: state.languages.map((language) {
              return language.copyWith(
                isSelected: selectedLanguageCodes.contains(language.code),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
