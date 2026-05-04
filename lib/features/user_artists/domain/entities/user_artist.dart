import 'package:equatable/equatable.dart';

class UserArtistDetail extends Equatable {
  final String artistId;
  final String? name;
  final String? avatarUrl;
  final String? coverUrl;
  final String? bio;
  final List<String> genres;
  final int? monthlyListeners;
  final List<UserArtistAlbum> albums;
  final List<UserArtistTrack> tracks;

  const UserArtistDetail({
    required this.artistId,
    this.name,
    this.avatarUrl,
    this.coverUrl,
    this.bio,
    this.genres = const [],
    this.monthlyListeners,
    this.albums = const [],
    this.tracks = const [],
  });

  @override
  List<Object?> get props => [
    artistId,
    name,
    avatarUrl,
    coverUrl,
    bio,
    genres,
    monthlyListeners,
    albums,
    tracks,
  ];
}

class UserArtistAlbum extends Equatable {
  final String albumId;
  final String title;
  final String? coverUrl;
  final String? releaseDate;

  const UserArtistAlbum({
    required this.albumId,
    required this.title,
    this.coverUrl,
    this.releaseDate,
  });

  @override
  List<Object?> get props => [albumId, title, coverUrl, releaseDate];
}

class UserArtistTrack extends Equatable {
  final String trackId;
  final String title;
  final int? duration;
  final int? playCount;
  final int? likesCount;
  final String? albumId;
  final String? coverUrl;
  final List<UserArtistTrackArtist> artists;

  const UserArtistTrack({
    required this.trackId,
    required this.title,
    this.duration,
    this.playCount,
    this.likesCount,
    this.albumId,
    this.coverUrl,
    this.artists = const [],
  });

  @override
  List<Object?> get props => [
    trackId,
    title,
    duration,
    playCount,
    likesCount,
    albumId,
    coverUrl,
    artists,
  ];
}

class UserArtistTrackArtist extends Equatable {
  final String artistId;
  final String? name;

  const UserArtistTrackArtist({required this.artistId, this.name});

  @override
  List<Object?> get props => [artistId, name];
}
