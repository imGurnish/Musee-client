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

final class UserPlaylistTrackAdded extends UserPlaylistEvent {
  final String playlistId;
  final String trackId;

  const UserPlaylistTrackAdded(this.playlistId, this.trackId);

  @override
  List<Object> get props => [playlistId, trackId];
}

final class UserPlaylistTrackRemoved extends UserPlaylistEvent {
  final String playlistId;
  final String trackId;

  const UserPlaylistTrackRemoved(this.playlistId, this.trackId);

  @override
  List<Object> get props => [playlistId, trackId];
}

final class UserPlaylistJoinRequested extends UserPlaylistEvent {
  final String playlistId;

  const UserPlaylistJoinRequested(this.playlistId);

  @override
  List<Object> get props => [playlistId];
}

final class UserPlaylistDeleted extends UserPlaylistEvent {
  final String playlistId;

  const UserPlaylistDeleted(this.playlistId);

  @override
  List<Object> get props => [playlistId];
}

final class UserPlaylistUpdated extends UserPlaylistEvent {
  final String playlistId;
  final String? name;
  final String? description;
  final bool? isPublic;
  final bool? isCollaborative;
  final String? coverPath;

  const UserPlaylistUpdated({
    required this.playlistId,
    this.name,
    this.description,
    this.isPublic,
    this.isCollaborative,
    this.coverPath,
  });

  @override
  List<Object> get props => [
        playlistId,
        name ?? '',
        description ?? '',
        isPublic ?? false,
        isCollaborative ?? false,
        coverPath ?? '',
      ];
}
