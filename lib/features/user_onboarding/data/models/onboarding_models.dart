import 'package:equatable/equatable.dart';

// ====================
// DTOs (Data Transfer Objects)
// ====================

class OnboardingUserDTO extends Equatable {
  final String userId;
  final String preferredLanguage;
  final List<String> favoriteGenres;
  final List<String> favoriteMoods;
  final List<String> favoriteArtists;
  final int randomnessPercentage;

  const OnboardingUserDTO({
    required this.userId,
    required this.preferredLanguage,
    required this.favoriteGenres,
    required this.favoriteMoods,
    required this.favoriteArtists,
    this.randomnessPercentage = 15,
  });

  // Convert to JSON for API/Database
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'preferred_language': preferredLanguage,
    'favorite_genres': favoriteGenres,
    'favorite_moods': favoriteMoods,
    'favorite_artists': favoriteArtists,
    'randomness_percentage': randomnessPercentage / 100,
  };

  // Create from API response
  factory OnboardingUserDTO.fromJson(Map<String, dynamic> json) {
    final rawRandomness = json['randomness_percentage'];
    final asNum = rawRandomness is num
        ? rawRandomness.toDouble()
        : double.tryParse(rawRandomness?.toString() ?? '0.15') ?? 0.15;
    final percentage = asNum <= 1 ? (asNum * 100).round() : asNum.round();

    return OnboardingUserDTO(
      userId: json['user_id'] as String,
      preferredLanguage: json['preferred_language'] as String? ?? 'en',
      favoriteGenres: List<String>.from(json['favorite_genres'] as List? ?? []),
      favoriteMoods: List<String>.from(json['favorite_moods'] as List? ?? []),
      favoriteArtists: List<String>.from(json['favorite_artists'] as List? ?? []),
      randomnessPercentage: percentage,
    );
  }

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

// ====================
// Models for Genre Selection
// ====================

class GenreModel extends Equatable {
  final String id;
  final String name;
  final String icon; // emoji or icon reference
  final bool isSelected;

  const GenreModel({
    required this.id,
    required this.name,
    required this.icon,
    this.isSelected = false,
  });

  GenreModel copyWith({
    String? id,
    String? name,
    String? icon,
    bool? isSelected,
  }) {
    return GenreModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [id, name, icon, isSelected];
}

// ====================
// Models for Mood Selection
// ====================

class MoodModel extends Equatable {
  final String id;
  final String name;
  final String icon;
  final String description;
  final bool isSelected;

  const MoodModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.isSelected = false,
  });

  MoodModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? description,
    bool? isSelected,
  }) {
    return MoodModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [id, name, icon, description, isSelected];
}

// ====================
// Models for Artist Selection
// ====================

class ArtistSearchModel extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final String? genre;
  final bool isSelected;

  const ArtistSearchModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.genre,
    this.isSelected = false,
  });

  ArtistSearchModel copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? genre,
    bool? isSelected,
  }) {
    return ArtistSearchModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      genre: genre ?? this.genre,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  factory ArtistSearchModel.fromJson(Map<String, dynamic> json) {
    return ArtistSearchModel(
      id: json['artist_id'] as String,
      name: json['name'] as String,
      imageUrl: json['image_url'] as String?,
      genre: json['genre'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, imageUrl, genre, isSelected];
}

// ====================
// Models for Language Selection
// ====================

class LanguageModel extends Equatable {
  final String code;
  final String name;
  final String nativeName;
  final bool isSelected;

  const LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    this.isSelected = false,
  });

  LanguageModel copyWith({
    String? code,
    String? name,
    String? nativeName,
    bool? isSelected,
  }) {
    return LanguageModel(
      code: code ?? this.code,
      name: name ?? this.name,
      nativeName: nativeName ?? this.nativeName,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  List<Object?> get props => [code, name, nativeName, isSelected];
}

// Predefined languages
final defaultLanguages = [
  const LanguageModel(code: 'en', name: 'English', nativeName: 'English'),
  const LanguageModel(code: 'hi', name: 'Hindi', nativeName: 'हिंदी'),
  const LanguageModel(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
  const LanguageModel(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
  const LanguageModel(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  const LanguageModel(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം'),
  const LanguageModel(code: 'mr', name: 'Marathi', nativeName: 'मराठी'),
  const LanguageModel(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી'),
  const LanguageModel(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ'),
  const LanguageModel(code: 'bn', name: 'Bengali', nativeName: 'বাংলা'),
];

// Predefined genres
final defaultGenres = [
  const GenreModel(id: 'pop', name: 'Pop', icon: '🎤'),
  const GenreModel(id: 'rock', name: 'Rock', icon: '🎸'),
  const GenreModel(id: 'hiphop', name: 'Hip-Hop', icon: '🎙️'),
  const GenreModel(id: 'jazz', name: 'Jazz', icon: '🎷'),
  const GenreModel(id: 'classical', name: 'Classical', icon: '🎻'),
  const GenreModel(id: 'electronic', name: 'Electronic', icon: '🎹'),
  const GenreModel(id: 'indie', name: 'Indie', icon: '🎵'),
  const GenreModel(id: 'folk', name: 'Folk', icon: '🎶'),
  const GenreModel(id: 'rnb', name: 'R&B', icon: '🎧'),
  const GenreModel(id: 'bollywood', name: 'Bollywood', icon: '🎬'),
  const GenreModel(id: 'bhojpuri', name: 'Bhojpuri', icon: '🎤'),
  const GenreModel(id: 'regional', name: 'Regional', icon: '🌍'),
];

// Predefined moods
final defaultMoods = [
  const MoodModel(
    id: 'energetic',
    name: 'Energetic',
    icon: '⚡',
    description: 'Upbeat and energizing',
  ),
  const MoodModel(
    id: 'chill',
    name: 'Chill',
    icon: '❄️',
    description: 'Relaxed and cool',
  ),
  const MoodModel(
    id: 'romantic',
    name: 'Romantic',
    icon: '💕',
    description: 'Romantic and sensual',
  ),
  const MoodModel(
    id: 'sad',
    name: 'Sad',
    icon: '😢',
    description: 'Melancholic and thoughtful',
  ),
  const MoodModel(
    id: 'party',
    name: 'Party',
    icon: '🎉',
    description: 'Fun and celebratory',
  ),
  const MoodModel(
    id: 'focus',
    name: 'Focus',
    icon: '🧠',
    description: 'Concentration and productivity',
  ),
  const MoodModel(
    id: 'workout',
    name: 'Workout',
    icon: '💪',
    description: 'Motivating and intense',
  ),
  const MoodModel(
    id: 'sleep',
    name: 'Sleep',
    icon: '😴',
    description: 'Peaceful and calming',
  ),
];
