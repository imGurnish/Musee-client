part of 'onboarding_bloc.dart';

class OnboardingState extends Equatable {
  final bool isLoading;
  final bool isSaving;
  final bool isSearching;
  final bool isCompleted;
  final String? error;
  final String? searchError;
  final List<LanguageModel> languages;
  final List<GenreModel> genres;
  final List<MoodModel> moods;
  final List<ArtistSearchModel> searchResults;
  final LanguageModel? selectedLanguage;
  final List<String> selectedGenres;
  final List<String> selectedMoods;
  final List<ArtistSearchModel> selectedArtists;
  final int randomnessPercentage;

  const OnboardingState({
    this.isLoading = false,
    this.isSaving = false,
    this.isSearching = false,
    this.isCompleted = false,
    this.error,
    this.searchError,
    this.languages = const [],
    this.genres = const [],
    this.moods = const [],
    this.searchResults = const [],
    this.selectedLanguage,
    this.selectedGenres = const [],
    this.selectedMoods = const [],
    this.selectedArtists = const [],
    this.randomnessPercentage = 15,
  });

  /// Initial state
  const OnboardingState.initial()
      : isLoading = false,
        isSaving = false,
        isSearching = false,
        isCompleted = false,
        error = null,
        searchError = null,
        languages = const [],
        genres = const [],
        moods = const [],
        searchResults = const [],
        selectedLanguage = null,
        selectedGenres = const [],
        selectedMoods = const [],
        selectedArtists = const [],
        randomnessPercentage = 15;

  OnboardingState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isSearching,
    bool? isCompleted,
    String? error,
    String? searchError,
    List<LanguageModel>? languages,
    List<GenreModel>? genres,
    List<MoodModel>? moods,
    List<ArtistSearchModel>? searchResults,
    LanguageModel? selectedLanguage,
    List<String>? selectedGenres,
    List<String>? selectedMoods,
    List<ArtistSearchModel>? selectedArtists,
    int? randomnessPercentage,
  }) {
    return OnboardingState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isSearching: isSearching ?? this.isSearching,
      isCompleted: isCompleted ?? this.isCompleted,
      error: error ?? this.error,
      searchError: searchError ?? this.searchError,
      languages: languages ?? this.languages,
      genres: genres ?? this.genres,
      moods: moods ?? this.moods,
      searchResults: searchResults ?? this.searchResults,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      selectedMoods: selectedMoods ?? this.selectedMoods,
      selectedArtists: selectedArtists ?? this.selectedArtists,
      randomnessPercentage: randomnessPercentage ?? this.randomnessPercentage,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isSaving,
    isSearching,
    isCompleted,
    error,
    searchError,
    languages,
    genres,
    moods,
    searchResults,
    selectedLanguage,
    selectedGenres,
    selectedMoods,
    selectedArtists,
    randomnessPercentage,
  ];
}
