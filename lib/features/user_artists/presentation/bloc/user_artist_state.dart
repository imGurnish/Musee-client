part of 'user_artist_bloc.dart';

class UserArtistState extends Equatable {
  final bool isLoading;
  final bool isLoadingMore;
  final UserArtistDetail? artist;
  final int albumPage;
  final int albumLimit;
  final bool hasReachedAlbumEnd;
  final String? error;

  const UserArtistState._({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.artist,
    this.albumPage = 0,
    this.albumLimit = 20,
    this.hasReachedAlbumEnd = false,
    this.error,
  });

  const UserArtistState.initial() : this._(isLoading: true);
  const UserArtistState.loading() : this._(isLoading: true);
  const UserArtistState.loaded(
    UserArtistDetail a, {
    int albumPage = 0,
    int albumLimit = 20,
    bool hasReachedAlbumEnd = false,
  }) : this._(
         artist: a,
         albumPage: albumPage,
         albumLimit: albumLimit,
         hasReachedAlbumEnd: hasReachedAlbumEnd,
       );
  const UserArtistState.error(String message) : this._(error: message);

  UserArtistState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    UserArtistDetail? artist,
    int? albumPage,
    int? albumLimit,
    bool? hasReachedAlbumEnd,
    String? error,
  }) {
    return UserArtistState._(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      artist: artist ?? this.artist,
      albumPage: albumPage ?? this.albumPage,
      albumLimit: albumLimit ?? this.albumLimit,
      hasReachedAlbumEnd: hasReachedAlbumEnd ?? this.hasReachedAlbumEnd,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    isLoading,
    isLoadingMore,
    artist,
    albumPage,
    albumLimit,
    hasReachedAlbumEnd,
    error,
  ];
}
