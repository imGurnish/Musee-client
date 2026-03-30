import 'package:equatable/equatable.dart';

/// Domain entity for user onboarding preferences
class OnboardingUser extends Equatable {
  final String userId;
  final String preferredLanguage;
  final List<String> favoriteGenres;
  final List<String> favoriteMoods;
  final List<String> favoriteArtists;
  final int randomnessPercentage;

  const OnboardingUser({
    required this.userId,
    required this.preferredLanguage,
    required this.favoriteGenres,
    required this.favoriteMoods,
    required this.favoriteArtists,
    this.randomnessPercentage = 15,
  });

  @override
  List<Object?> get props => [
    userId,
    preferredLanguage,
    favoriteGenres,
    favoriteMoods,
    favoriteArtists,
    randomnessPercentage,
  ];
}

/// Domain entity for genre
class Genre extends Equatable {
  final String id;
  final String name;
  final String icon;

  const Genre({
    required this.id,
    required this.name,
    required this.icon,
  });

  @override
  List<Object?> get props => [id, name, icon];
}

/// Domain entity for mood
class Mood extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String description;

  const Mood({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
  });

  @override
  List<Object?> get props => [id, name, icon, description];
}

/// Domain entity for artist
class Artist extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final String? genre;

  const Artist({
    required this.id,
    required this.name,
    this.imageUrl,
    this.genre,
  });

  @override
  List<Object?> get props => [id, name, imageUrl, genre];
}

/// Domain entity for language
class Language extends Equatable {
  final String code;
  final String name;
  final String nativeName;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  @override
  List<Object?> get props => [code, name, nativeName];
}
