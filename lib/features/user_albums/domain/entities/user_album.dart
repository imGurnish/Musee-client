import 'package:equatable/equatable.dart';

class UserAlbumDetail extends Equatable {
  final String albumId;
  final String title;
  final String? coverUrl;
  final String? releaseDate; // YYYY-MM-DD
  final List<UserAlbumArtist> artists;
  final List<UserAlbumTrack> tracks;
  final bool isFromCache;
  final Set<String> cachedTrackIds;
  final Set<String> offlineTrackIds;

  const UserAlbumDetail({
    required this.albumId,
    required this.title,
    required this.coverUrl,
    required this.releaseDate,
    required this.artists,
    required this.tracks,
    this.isFromCache = false,
    this.cachedTrackIds = const <String>{},
    this.offlineTrackIds = const <String>{},
  });

  bool get hasAnyOfflineTrack => offlineTrackIds.isNotEmpty;

  bool isTrackCached(String trackId) => cachedTrackIds.contains(trackId);

  bool isTrackOffline(String trackId) => offlineTrackIds.contains(trackId);

  @override
  List<Object?> get props => [
    albumId,
    title,
    coverUrl,
    releaseDate,
    artists,
    tracks,
    isFromCache,
    cachedTrackIds,
    offlineTrackIds,
  ];
}

class UserAlbumArtist extends Equatable {
  final String artistId;
  final String? name;
  final String? avatarUrl;

  const UserAlbumArtist({required this.artistId, this.name, this.avatarUrl});

  @override
  List<Object?> get props => [artistId, name, avatarUrl];
}

class UserAlbumTrack extends Equatable {
  final String trackId;
  final String title;
  final int duration; // seconds
  final bool isExplicit;
  final List<UserAlbumArtist> artists;

  const UserAlbumTrack({
    required this.trackId,
    required this.title,
    required this.duration,
    required this.isExplicit,
    required this.artists,
  });

  @override
  List<Object?> get props => [trackId, title, duration, isExplicit, artists];
}
