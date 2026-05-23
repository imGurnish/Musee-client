import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/usecases/get_user_playlist.dart';
import 'package:musee/features/user_playlists/domain/usecases/add_playlist_track.dart';
import 'package:musee/features/user_playlists/domain/usecases/remove_playlist_track.dart';
import 'package:musee/features/user_playlists/domain/usecases/join_playlist.dart';
import 'package:musee/features/user_playlists/domain/usecases/delete_playlist.dart';
import 'package:musee/features/user_playlists/domain/usecases/update_playlist.dart';

part 'user_playlist_event.dart';
part 'user_playlist_state.dart';

class UserPlaylistBloc extends Bloc<UserPlaylistEvent, UserPlaylistState> {
  final GetUserPlaylist _getPlaylist;
  final AddPlaylistTrack _addTrack;
  final RemovePlaylistTrack _removeTrack;
  final JoinPlaylist _joinPlaylist;
  final DeletePlaylist _deletePlaylist;
  final UpdatePlaylist _updatePlaylist;

  UserPlaylistBloc(
    this._getPlaylist,
    this._addTrack,
    this._removeTrack,
    this._joinPlaylist,
    this._deletePlaylist,
    this._updatePlaylist,
  ) : super(const UserPlaylistState.initial()) {
    on<UserPlaylistLoadRequested>(_onLoad);
    on<UserPlaylistTrackAdded>(_onTrackAdded);
    on<UserPlaylistTrackRemoved>(_onTrackRemoved);
    on<UserPlaylistJoinRequested>(_onJoinRequested);
    on<UserPlaylistDeleted>(_onDeleted);
    on<UserPlaylistUpdated>(_onUpdated);
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

  Future<void> _onTrackAdded(
    UserPlaylistTrackAdded event,
    Emitter<UserPlaylistState> emit,
  ) async {
    final currentPlaylist = state.playlist;
    try {
      final updated = await _addTrack(event.playlistId, event.trackId);
      emit(UserPlaylistState.loaded(updated));
    } catch (e) {
      if (currentPlaylist != null) {
        emit(UserPlaylistState(playlist: currentPlaylist, error: e.toString()));
      } else {
        emit(UserPlaylistState.error(e.toString()));
      }
    }
  }

  Future<void> _onTrackRemoved(
    UserPlaylistTrackRemoved event,
    Emitter<UserPlaylistState> emit,
  ) async {
    final currentPlaylist = state.playlist;
    try {
      await _removeTrack(event.playlistId, event.trackId);
      // Reload playlist detail to fetch updated list
      final updated = await _getPlaylist(event.playlistId, forceRefresh: true);
      emit(UserPlaylistState.loaded(updated));
    } catch (e) {
      if (currentPlaylist != null) {
        emit(UserPlaylistState(playlist: currentPlaylist, error: e.toString()));
      } else {
        emit(UserPlaylistState.error(e.toString()));
      }
    }
  }

  Future<void> _onJoinRequested(
    UserPlaylistJoinRequested event,
    Emitter<UserPlaylistState> emit,
  ) async {
    emit(const UserPlaylistState.loading());
    try {
      final updated = await _joinPlaylist(event.playlistId);
      emit(UserPlaylistState.loaded(updated));
    } catch (e) {
      emit(UserPlaylistState.error(e.toString()));
    }
  }

  Future<void> _onDeleted(
    UserPlaylistDeleted event,
    Emitter<UserPlaylistState> emit,
  ) async {
    emit(const UserPlaylistState.loading());
    try {
      await _deletePlaylist(event.playlistId);
      emit(const UserPlaylistState.deleted());
    } catch (e) {
      emit(UserPlaylistState.error(e.toString()));
    }
  }

  Future<void> _onUpdated(
    UserPlaylistUpdated event,
    Emitter<UserPlaylistState> emit,
  ) async {
    final currentPlaylist = state.playlist;
    emit(const UserPlaylistState.loading());
    try {
      final updated = await _updatePlaylist(
        playlistId: event.playlistId,
        name: event.name,
        description: event.description,
        isPublic: event.isPublic,
        isCollaborative: event.isCollaborative,
        coverPath: event.coverPath,
      );
      emit(UserPlaylistState.loaded(updated));
    } catch (e) {
      if (currentPlaylist != null) {
        emit(UserPlaylistState(playlist: currentPlaylist, error: e.toString()));
      } else {
        emit(UserPlaylistState.error(e.toString()));
      }
    }
  }
}
