part of 'user_playlist_bloc.dart';

class UserPlaylistState extends Equatable {
  final UserPlaylistDetail? playlist;
  final bool isLoading;
  final String? error;

  const UserPlaylistState({
    this.playlist,
    this.isLoading = false,
    this.error,
  });

  const UserPlaylistState.initial()
      : playlist = null,
        isLoading = false,
        error = null;

  const UserPlaylistState.loading()
      : playlist = null,
        isLoading = true,
        error = null;

  const UserPlaylistState.loaded(UserPlaylistDetail this.playlist)
      : isLoading = false,
        error = null;

  const UserPlaylistState.error(String this.error)
      : playlist = null,
        isLoading = false;

  @override
  List<Object?> get props => [playlist, isLoading, error];
}
