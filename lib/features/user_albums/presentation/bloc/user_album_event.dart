part of 'user_album_bloc.dart';

abstract class UserAlbumEvent extends Equatable {
  const UserAlbumEvent();
  @override
  List<Object?> get props => [];
}

class UserAlbumLoadRequested extends UserAlbumEvent {
  final String albumId;
  final bool forceRefresh;
  const UserAlbumLoadRequested(this.albumId, {this.forceRefresh = false});

  @override
  List<Object?> get props => [albumId, forceRefresh];
}
