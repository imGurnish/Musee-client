part of 'user_playlist_bloc.dart';

class UserPlaylistState extends Equatable {
  final UserPlaylistDetail? playlist;
  final bool isLoading;
  final String? error;
  final bool isDeleted;

  const UserPlaylistState({
    this.playlist,
    this.isLoading = false,
    this.error,
    this.isDeleted = false,
  });

  const UserPlaylistState.initial()
      : playlist = null,
        isLoading = false,
        error = null,
        isDeleted = false;

  const UserPlaylistState.loading()
      : playlist = null,
        isLoading = true,
        error = null,
        isDeleted = false;

  const UserPlaylistState.loaded(UserPlaylistDetail this.playlist)
      : isLoading = false,
        error = null,
        isDeleted = false;

  const UserPlaylistState.error(String this.error)
      : playlist = null,
        isLoading = false,
        isDeleted = false;

  const UserPlaylistState.deleted()
      : playlist = null,
        isLoading = false,
        error = null,
        isDeleted = true;

  @override
  List<Object?> get props => [playlist, isLoading, error, isDeleted];
}
