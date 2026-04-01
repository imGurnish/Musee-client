import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/usecases/get_user_playlist.dart';

part 'user_playlist_event.dart';
part 'user_playlist_state.dart';

class UserPlaylistBloc extends Bloc<UserPlaylistEvent, UserPlaylistState> {
  final GetUserPlaylist _getPlaylist;

  UserPlaylistBloc(this._getPlaylist)
      : super(const UserPlaylistState.initial()) {
    on<UserPlaylistLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    UserPlaylistLoadRequested event,
    Emitter<UserPlaylistState> emit,
  ) async {
    emit(const UserPlaylistState.loading());
    try {
      final playlist = await _getPlaylist(
        event.playlistId,
        forceRefresh: event.forceRefresh,
      );
      emit(UserPlaylistState.loaded(playlist));
    } catch (e) {
      emit(UserPlaylistState.error(e.toString()));
    }
  }
}
