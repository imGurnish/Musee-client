import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/onboarding_models.dart';

abstract class OnboardingRemoteDataSource {
  /// Get languages available for selection
  Future<List<LanguageModel>> getAvailableLanguages();

  /// Get genres available for selection
  Future<List<GenreModel>> getAvailableGenres();

  /// Get moods available for selection
  Future<List<MoodModel>> getAvailableMoods();

  /// Search for artists by query
  Future<List<ArtistSearchModel>> searchArtists(
    String query,
    List<String> languages,
  );

  /// Get similar artists for an artist
  Future<List<ArtistSearchModel>> getSimilarArtists(String artistId);

  /// Save onboarding preferences for user
  Future<void> saveOnboardingPreferences(OnboardingUserDTO preferences);

  /// Get user's existing onboarding preferences
  Future<OnboardingUserDTO> getUserOnboardingPreferences(String userId);
}

class OnboardingRemoteDataSourceImpl implements OnboardingRemoteDataSource {
  final SupabaseClient supabaseClient;

  OnboardingRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Future<List<LanguageModel>> getAvailableLanguages() async {
    return defaultLanguages;
  }

  @override
  Future<List<GenreModel>> getAvailableGenres() async {
    return defaultGenres;
  }

  @override
  Future<List<MoodModel>> getAvailableMoods() async {
    return defaultMoods;
  }

  @override
  Future<List<ArtistSearchModel>> searchArtists(
    String query,
    List<String> languages,
  ) async {
    try {
      final token = supabaseClient.auth.currentSession?.accessToken;
      final trimmed = query.trim();
      
      String urlStr = '${AppSecrets.backendUrl}/api/user/artists?page=0&limit=20';
      if (trimmed.isNotEmpty) {
        urlStr += '&q=${Uri.encodeQueryComponent(trimmed)}';
      }
      if (languages.isNotEmpty) {
        urlStr += '&languages=${Uri.encodeQueryComponent(languages.join(','))}';
      }
      final uri = Uri.parse(urlStr);

      final response = await http.get(
        uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode != 200) {
        throw Exception('Artists API failed: ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      final artists = _extractItems(decoded);

      return artists
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return ArtistSearchModel(
              id: (map['artist_id'] ?? map['id'] ?? '').toString(),
              name: (map['name'] ?? '').toString(),
              imageUrl:
                  map['avatar_url']?.toString() ?? map['image_url']?.toString(),
              genre: map['genre']?.toString(),
            );
          })
          .where((artist) => artist.id.isNotEmpty && artist.name.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to search artists: $e');
    }
  }

  @override
  Future<List<ArtistSearchModel>> getSimilarArtists(String artistId) async {
    try {
      final token = supabaseClient.auth.currentSession?.accessToken;
      final uri = Uri.parse(
        '${AppSecrets.backendUrl}/api/user/artists/$artistId/similar?limit=100',
      );

      final response = await http.get(
        uri,
        headers: token != null ? {'Authorization': 'Bearer $token'} : {},
      );

      if (response.statusCode != 200) {
        throw Exception('Similar artists API failed: ${response.statusCode}');
      }

      final decoded = json.decode(response.body);
      final list = decoded is List ? decoded : const [];

      return list
          .map((item) {
            final map = Map<String, dynamic>.from(item as Map);
            return ArtistSearchModel(
              id: (map['artist_id'] ?? map['id'] ?? '').toString(),
              name: (map['name'] ?? '').toString(),
              imageUrl:
                  map['avatar_url']?.toString() ?? map['image_url']?.toString(),
              genre: map['genre']?.toString(),
            );
          })
          .where((artist) => artist.id.isNotEmpty && artist.name.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to get similar artists: $e');
    }
  }

  @override
  Future<void> saveOnboardingPreferences(OnboardingUserDTO preferences) async {
    try {
      final authUserId = supabaseClient.auth.currentUser?.id;
      if (authUserId == null) {
        throw Exception('No authenticated Supabase session found');
      }

      await supabaseClient.from('user_onboarding_preferences').upsert({
        // Under RLS, writes must target the authenticated user's row.
        'user_id': authUserId,
        'preferred_languages': preferences.preferredLanguages,
        'favorite_genres': preferences.favoriteGenres,
        'favorite_moods': preferences.favoriteMoods,
        'favorite_artists': preferences.favoriteArtists,
        'randomness_percentage': preferences.randomnessPercentage / 100,
        'completed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (e) {
      throw Exception('Failed to save onboarding preferences: $e');
    }
  }

  @override
  Future<OnboardingUserDTO> getUserOnboardingPreferences(String userId) async {
    try {
      final resolvedUserId = supabaseClient.auth.currentUser?.id ?? userId;

      final data = await supabaseClient
          .from('user_onboarding_preferences')
          .select(
            'user_id, preferred_languages, favorite_genres, favorite_moods, favorite_artists, randomness_percentage',
          )
          .eq('user_id', resolvedUserId)
          .maybeSingle();

      if (data == null) {
        throw Exception('Onboarding preferences not found');
      }

      return OnboardingUserDTO.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw Exception('Failed to get onboarding preferences: $e');
    }
  }

  List<dynamic> _extractItems(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map<String, dynamic>) {
      final items = decoded['items'];
      if (items is List) return items;
      final data = decoded['data'];
      if (data is List) return data;
      final artists = decoded['artists'];
      if (artists is List) return artists;
      final results = decoded['results'];
      if (results is List) return results;
    }
    return const [];
  }
}
