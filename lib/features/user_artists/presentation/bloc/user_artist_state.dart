part of 'user_artist_bloc.dart';

class UserArtistState extends Equatable {
  final bool isLoading;
  final bool isLoadingMore;
  final UserArtistDetail? artist;

  // Albums pagination
  final int albumPage;
  final int albumLimit;
  final bool hasReachedAlbumEnd;

  // Singles pagination (independent cursor)
  final int singlesPage;
  final int singlesLimit;
  final bool hasReachedSinglesEnd;

  final String? error;

  const UserArtistState._({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.artist,
    this.albumPage = 0,
    this.albumLimit = 20,
    this.hasReachedAlbumEnd = false,
    this.singlesPage = 0,
    this.singlesLimit = 20,
    this.hasReachedSinglesEnd = false,
    this.error,
  });

  const UserArtistState.initial() : this._(isLoading: true);
  const UserArtistState.loading() : this._(isLoading: true);

  const UserArtistState.loaded(
    UserArtistDetail a, {
    int albumPage = 0,
    int albumLimit = 20,
    bool hasReachedAlbumEnd = false,
    int singlesPage = 0,
    int singlesLimit = 20,
    bool hasReachedSinglesEnd = false,
  }) : this._(
         artist: a,
         albumPage: albumPage,
         albumLimit: albumLimit,
         hasReachedAlbumEnd: hasReachedAlbumEnd,
         singlesPage: singlesPage,
         singlesLimit: singlesLimit,
         hasReachedSinglesEnd: hasReachedSinglesEnd,
       );

  const UserArtistState.error(String message) : this._(error: message);

  /// Both albums and singles have been fully loaded.
  bool get hasReachedAllEnd => hasReachedAlbumEnd && hasReachedSinglesEnd;

  UserArtistState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    UserArtistDetail? artist,
    int? albumPage,
    int? albumLimit,
    bool? hasReachedAlbumEnd,
    int? singlesPage,
    int? singlesLimit,
    bool? hasReachedSinglesEnd,
    String? error,
  }) {
    return UserArtistState._(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      artist: artist ?? this.artist,
      albumPage: albumPage ?? this.albumPage,
      albumLimit: albumLimit ?? this.albumLimit,
      hasReachedAlbumEnd: hasReachedAlbumEnd ?? this.hasReachedAlbumEnd,
      singlesPage: singlesPage ?? this.singlesPage,
      singlesLimit: singlesLimit ?? this.singlesLimit,
      hasReachedSinglesEnd: hasReachedSinglesEnd ?? this.hasReachedSinglesEnd,
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
    singlesPage,
    singlesLimit,
    hasReachedSinglesEnd,
    error,
  ];
}
