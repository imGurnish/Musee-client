import 'dart:convert';

/// Represents an application user and maps to the `public.users` table.
///
/// Notes:
/// - Fields are nullable where the DB allows nulls.
/// - `playlists` is a list of UUIDs (stored as uuid[] in Postgres).
/// - `favorites` and `settings` are JSONB and represented as maps here.
class User {
  final String id; // maps to user_id
  final String? email; // optional: may come from auth.users join
  final String name;

  final SubscriptionType subscriptionType;
  final String? planId;
  final String avatarUrl;

  final List<String> playlists;
  final Map<String, dynamic> favorites;

  final int followersCount;
  final int followingsCount;

  final DateTime? lastLoginAt;
  final Map<String, dynamic> settings;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final UserType userType;

  User({
    required this.id,
    required this.name,
    this.email,
    this.subscriptionType = SubscriptionType.free,
    this.planId,
    this.avatarUrl =
        'https://xvpputhovrhgowfkjhfv.supabase.co/storage/v1/object/public/avatars/users/default_avatar.png',
    List<String>? playlists,
    Map<String, dynamic>? favorites,
    this.followersCount = 0,
    this.followingsCount = 0,
    this.lastLoginAt,
    Map<String, dynamic>? settings,
    this.createdAt,
    this.updatedAt,
    this.userType = UserType.listener,
  }) : playlists = playlists ?? <String>[],
       favorites = favorites ?? <String, dynamic>{},
       settings = settings ?? <String, dynamic>{};

  User copyWith({
    String? id,
    String? email,
    String? name,
    SubscriptionType? subscriptionType,
    String? planId,
    String? avatarUrl,
    List<String>? playlists,
    Map<String, dynamic>? favorites,
    int? followersCount,
    int? followingsCount,
    DateTime? lastLoginAt,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserType? userType,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      subscriptionType: subscriptionType ?? this.subscriptionType,
      planId: planId ?? this.planId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      playlists: playlists ?? List<String>.from(this.playlists),
      favorites: favorites ?? Map<String, dynamic>.from(this.favorites),
      followersCount: followersCount ?? this.followersCount,
      followingsCount: followingsCount ?? this.followingsCount,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      settings: settings ?? Map<String, dynamic>.from(this.settings),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userType: userType ?? this.userType,
    );
  }

  /// Convert User to Map suitable for JSON encoding / saving to DB.
  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      if (email != null) 'email': email,
      'name': name,
      'subscription_type': subscriptionType.value,
      'plan_id': planId,
      'avatar_url': avatarUrl,
      'playlists': playlists,
      'favorites': favorites,
      'followers_count': followersCount,
      'followings_count': followingsCount,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'settings': settings,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'user_type': userType.value,
    };
  }

  /// Create User from a Map (e.g. JSON decoded from API or DB row map).
  factory User.fromJson(Map<String, dynamic> json) {
    // helper to parse list of uuids from various driver formats
    List<String> parsePlaylists(dynamic input) {
      if (input == null) return <String>[];
      if (input is List) return input.map((e) => e.toString()).toList();
      if (input is String) {
        // Sometimes Postgres drivers return '{uuid1,uuid2}' style
        final cleaned = input.replaceAll(RegExp(r'[{}]'), '');
        if (cleaned.trim().isEmpty) return <String>[];
        return cleaned
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return <String>[];
    }

    Map<String, dynamic> parseMap(dynamic input) {
      if (input == null) return <String, dynamic>{};
      if (input is Map) return Map<String, dynamic>.from(input);
      if (input is String) {
        try {
          final decoded = jsonDecode(input);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {
          return <String, dynamic>{};
        }
      }
      return <String, dynamic>{};
    }

    DateTime? parseDateTime(dynamic input) {
      if (input == null) return null;
      if (input is DateTime) return input;
      if (input is String) return DateTime.tryParse(input);
      return null;
    }

    final subTypeStr = (json['subscription_type'] ?? json['subscriptionType'])
        ?.toString();
    final userTypeStr = (json['user_type'] ?? json['userType'])?.toString();

    return User(
      id: (json['user_id'] ?? json['id']).toString(),
      name: (json['name'] ?? '').toString(),
      email: json['email']?.toString(),
      subscriptionType: SubscriptionType.fromValue(subTypeStr),
      planId: json['plan_id']?.toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl'] ?? '') == ''
          ? 'https://xvpputhovrhgowfkjhfv.supabase.co/storage/v1/object/public/avatars/users/default_avatar.png'
          : (json['avatar_url'] ?? json['avatarUrl']).toString(),
      playlists: parsePlaylists(json['playlists'] ?? json['playlists_array']),
      favorites: parseMap(json['favorites']),
      followersCount: (json['followers_count'] ?? 0) is int
          ? (json['followers_count'] ?? 0) as int
          : int.tryParse((json['followers_count'] ?? '0').toString()) ?? 0,
      followingsCount: (json['followings_count'] ?? 0) is int
          ? (json['followings_count'] ?? 0) as int
          : int.tryParse((json['followings_count'] ?? '0').toString()) ?? 0,
      lastLoginAt: parseDateTime(json['last_login_at'] ?? json['lastLoginAt']),
      settings: parseMap(json['settings']),
      createdAt: parseDateTime(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTime(json['updated_at'] ?? json['updatedAt']),
      userType: UserType.fromValue(userTypeStr),
    );
  }
}

enum SubscriptionType {
  free('free'),
  premium('premium'),
  trial('trial');

  final String value;
  const SubscriptionType(this.value);

  static SubscriptionType fromValue(String? v) {
    if (v == null) return SubscriptionType.free;
    final s = v.toLowerCase();
    for (final t in SubscriptionType.values) {
      if (t.value == s) return t;
    }
    return SubscriptionType.free;
  }
}

enum UserType {
  listener('listener'),
  artist('artist');

  final String value;
  const UserType(this.value);

  static UserType fromValue(String? v) {
    if (v == null) return UserType.listener;
    final s = v.toLowerCase();
    for (final t in UserType.values) {
      if (t.value == s) return t;
    }
    return UserType.listener;
  }
}
