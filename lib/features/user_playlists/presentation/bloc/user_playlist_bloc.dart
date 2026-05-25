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

      // Reconcile optimistic placeholders with authoritative server payload.
      try {
        var reconciled = _preservePendingAddedTrack(
          optimistic: updated,
          refreshed: await _getPlaylist(
            event.playlistId,
            forceRefresh: true,
          ),
          addedTrackId: event.trackId,
        );
        emit(UserPlaylistState.loaded(reconciled));

        // If backend/cache is briefly stale, retry a few times so sync shimmer
        // does not get stuck indefinitely.
        if (_isTrackStillSyncing(reconciled, event.trackId)) {
          for (var i = 0; i < 3; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 900));
            final refreshed = await _getPlaylist(
              event.playlistId,
              forceRefresh: true,
            );
            reconciled = _preservePendingAddedTrack(
              optimistic: updated,
              refreshed: refreshed,
              addedTrackId: event.trackId,
            );
            emit(UserPlaylistState.loaded(reconciled));
            if (!_isTrackStillSyncing(reconciled, event.trackId)) break;
          }
        }

        // Final safeguard: if track exists but backend still reports stale
        // syncing state, clear only the visual sync flag to avoid permanent shimmer.
        if (_isTrackStillSyncing(reconciled, event.trackId)) {
          final normalizedTracks = reconciled.tracks
              .map(
                (t) => t.trackId == event.trackId
                    ? UserPlaylistTrack(
                        trackId: t.trackId,
                        title: t.title,
                        duration: t.duration,
                        isExplicit: t.isExplicit,
                        isSyncing: false,
                        coverUrl: t.coverUrl,
                        artists: t.artists,
                      )
                    : t,
              )
              .toList(growable: false);

          final normalizedDuration = normalizedTracks.fold<int>(
            0,
            (sum, t) => sum + t.duration,
          );

          emit(
            UserPlaylistState.loaded(
              UserPlaylistDetail(
                playlistId: reconciled.playlistId,
                name: reconciled.name,
                coverUrl: reconciled.coverUrl,
                description: reconciled.description,
                artists: reconciled.artists,
                tracks: normalizedTracks,
                isPublic: reconciled.isPublic,
                isCollaborative: reconciled.isCollaborative,
                collaborators: reconciled.collaborators,
                totalTracks: normalizedTracks.length,
                totalDuration: normalizedDuration,
                createdAt: reconciled.createdAt,
                isFromCache: reconciled.isFromCache,
                cachedTrackIds: reconciled.cachedTrackIds,
                offlineTrackIds: reconciled.offlineTrackIds,
              ),
            ),
          );
        }
      } catch (_) {}
    } catch (e) {
      if (currentPlaylist != null) {
        emit(UserPlaylistState(playlist: currentPlaylist, error: e.toString()));
      } else {
        emit(UserPlaylistState.error(e.toString()));
      }
    }
  }

  bool _isTrackStillSyncing(UserPlaylistDetail playlist, String trackId) {
    for (final t in playlist.tracks) {
      if (t.trackId == trackId) return t.isSyncing;
    }
    return false;
  }

  UserPlaylistDetail _preservePendingAddedTrack({
    required UserPlaylistDetail optimistic,
    required UserPlaylistDetail refreshed,
    required String addedTrackId,
  }) {
    if (refreshed.tracks.any((t) => t.trackId == addedTrackId)) {
      return refreshed;
    }

    final pending = optimistic.tracks.where((t) => t.trackId == addedTrackId);
    if (pending.isEmpty) {
      return refreshed;
    }

    final mergedTracks = List<UserPlaylistTrack>.from(refreshed.tracks)
      ..addAll(
        pending.where(
          (t) => !refreshed.tracks.any((r) => r.trackId == t.trackId),
        ),
      );

    final mergedDuration = mergedTracks.fold<int>(0, (sum, t) => sum + t.duration);

    return UserPlaylistDetail(
      playlistId: refreshed.playlistId,
      name: refreshed.name,
      coverUrl: refreshed.coverUrl,
      description: refreshed.description,
      artists: refreshed.artists,
      tracks: mergedTracks,
      isPublic: refreshed.isPublic,
      isCollaborative: refreshed.isCollaborative,
      collaborators: refreshed.collaborators,
      totalTracks: mergedTracks.length,
      totalDuration: mergedDuration,
      createdAt: refreshed.createdAt,
      isFromCache: refreshed.isFromCache,
      cachedTrackIds: refreshed.cachedTrackIds,
      offlineTrackIds: refreshed.offlineTrackIds,
    );
  }

  Future<void> _onTrackRemoved(
    UserPlaylistTrackRemoved event,
    Emitter<UserPlaylistState> emit,
  ) async {
    final currentPlaylist = state.playlist;
    try {
      await _removeTrack(event.playlistId, event.trackId);
      // Load cached/merged playlist immediately (repository will reconcile in background)
      final updated = await _getPlaylist(event.playlistId, forceRefresh: false);
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
