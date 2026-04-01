part of 'user_playlist_bloc.dart';

sealed class UserPlaylistEvent extends Equatable {
  const UserPlaylistEvent();

  @override
  List<Object> get props => [];
}

final class UserPlaylistLoadRequested extends UserPlaylistEvent {
  final String playlistId;
  final bool forceRefresh;

  const UserPlaylistLoadRequested(
    this.playlistId, {
    this.forceRefresh = false,
  });

  @override
  List<Object> get props => [playlistId, forceRefresh];
}
