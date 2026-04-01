import 'package:equatable/equatable.dart';

class UserPlaylistDetail extends Equatable {
  final String playlistId;
  final String name;
  final String? coverUrl;
  final String? description;
  final List<UserPlaylistArtist> artists; // creator info
  final List<UserPlaylistTrack> tracks;
  final bool isPublic;
  final int totalTracks;
  final int totalDuration; // in seconds
  final String? createdAt;
  final bool isFromCache;
  final Set<String> cachedTrackIds;
  final Set<String> offlineTrackIds;

  const UserPlaylistDetail({
    required this.playlistId,
    required this.name,
    required this.coverUrl,
    required this.description,
    required this.artists,
    required this.tracks,
    required this.isPublic,
    required this.totalTracks,
    required this.totalDuration,
    required this.createdAt,
    this.isFromCache = false,
    this.cachedTrackIds = const <String>{},
    this.offlineTrackIds = const <String>{},
  });

  bool get hasAnyOfflineTrack => offlineTrackIds.isNotEmpty;

  bool isTrackCached(String trackId) => cachedTrackIds.contains(trackId);

  bool isTrackOffline(String trackId) => offlineTrackIds.contains(trackId);

  @override
  List<Object?> get props => [
    playlistId,
    name,
    coverUrl,
    description,
    artists,
    tracks,
    isPublic,
    totalTracks,
    totalDuration,
    createdAt,
    isFromCache,
    cachedTrackIds,
    offlineTrackIds,
  ];
}

class UserPlaylistArtist extends Equatable {
  final String artistId;
  final String? name;
  final String? avatarUrl;

  const UserPlaylistArtist({
    required this.artistId,
    this.name,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [artistId, name, avatarUrl];
}

class UserPlaylistTrack extends Equatable {
  final String trackId;
  final String title;
  final int duration; // seconds
  final bool isExplicit;
  final List<UserPlaylistArtist> artists;

  const UserPlaylistTrack({
    required this.trackId,
    required this.title,
    required this.duration,
    required this.isExplicit,
    required this.artists,
  });

  @override
  List<Object?> get props => [trackId, title, duration, isExplicit, artists];
}
