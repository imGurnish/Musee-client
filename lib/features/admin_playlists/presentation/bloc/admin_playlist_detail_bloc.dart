import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/admin_playlists/data/models/track_search_model.dart';
import 'package:musee/features/admin_playlists/domain/entities/playlist.dart';
import 'package:musee/features/admin_playlists/domain/usecases/add_track_to_playlist.dart';
import 'package:musee/features/admin_playlists/domain/usecases/get_playlist_details.dart';
import 'package:musee/features/admin_playlists/domain/usecases/remove_track_from_playlist.dart';
import 'package:musee/features/admin_playlists/domain/usecases/search_tracks.dart';

part 'admin_playlist_detail_event.dart';
part 'admin_playlist_detail_state.dart';

class AdminPlaylistDetailBloc
    extends Bloc<AdminPlaylistDetailEvent, AdminPlaylistDetailState> {
  final GetPlaylistDetails getPlaylistDetails;
  final SearchTracks searchTracks;
  final AddTrackToPlaylist addTrackToPlaylist;
  final RemoveTrackFromPlaylist removeTrackFromPlaylist;

  AdminPlaylistDetailBloc({
    required this.getPlaylistDetails,
    required this.searchTracks,
    required this.addTrackToPlaylist,
    required this.removeTrackFromPlaylist,
  }) : super(const AdminPlaylistDetailInitial()) {
    on<LoadPlaylistDetails>(_onLoadPlaylistDetails);
    on<SearchTracksEvent>(_onSearchTracks);
    on<AddTrackEvent>(_onAddTrack);
    on<RemoveTrackEvent>(_onRemoveTrack);
  }

  Future<void> _onLoadPlaylistDetails(
    LoadPlaylistDetails event,
    Emitter<AdminPlaylistDetailState> emit,
  ) async {
    emit(const AdminPlaylistDetailLoading());
    final result = await getPlaylistDetails(event.playlistId);
    result.fold(
      (failure) =>
          emit(AdminPlaylistDetailError(failure.message)),
      (playlist) => emit(AdminPlaylistDetailLoaded(playlist: playlist)),
    );
  }

  Future<void> _onSearchTracks(
    SearchTracksEvent event,
    Emitter<AdminPlaylistDetailState> emit,
  ) async {
    if (state is! AdminPlaylistDetailLoaded) {
      return;
    }
    final currentState = state as AdminPlaylistDetailLoaded;
    emit(currentState.copyWith(isSearching: true, error: null));

    final result = await searchTracks(
      SearchTracksParams(
        page: event.page,
        limit: 20,
        query: event.query,
      ),
    );

    result.fold(
      (failure) =>
          emit(currentState.copyWith(isSearching: false, error: failure.message)),
      (data) {
        final (items, total, page, limit) = data;
        emit(currentState.copyWith(
          searchResults: items,
          searchTotal: total,
          searchPage: page,
          searchQuery: event.query,
          isSearching: false,
          error: null,
        ));
      },
    );
  }

  Future<void> _onAddTrack(
    AddTrackEvent event,
    Emitter<AdminPlaylistDetailState> emit,
  ) async {
    if (state is! AdminPlaylistDetailLoaded) {
      return;
    }
    final currentState = state as AdminPlaylistDetailLoaded;
    emit(currentState.copyWith(isAddingTrack: true, error: null));

    final result = await addTrackToPlaylist(
      AddTrackToPlaylistParams(
        playlistId: currentState.playlist.playlistId,
        trackId: event.trackId,
      ),
    );

    result.fold(
      (failure) =>
          emit(currentState.copyWith(isAddingTrack: false, error: failure.message)),
      (updatedPlaylist) {
        emit(currentState.copyWith(
          playlist: updatedPlaylist,
          isAddingTrack: false,
          error: null,
        ));
      },
    );
  }

  Future<void> _onRemoveTrack(
    RemoveTrackEvent event,
    Emitter<AdminPlaylistDetailState> emit,
  ) async {
    if (state is! AdminPlaylistDetailLoaded) {
      return;
    }
    final currentState = state as AdminPlaylistDetailLoaded;
    emit(currentState.copyWith(isRemovingTrack: true, error: null));

    final result = await removeTrackFromPlaylist(
      RemoveTrackFromPlaylistParams(
        playlistId: currentState.playlist.playlistId,
        trackId: event.trackId,
      ),
    );

    result.fold(
      (failure) =>
          emit(currentState.copyWith(isRemovingTrack: false, error: failure.message)),
      (_) {
        // Reload the playlist details to get the updated track list
        add(LoadPlaylistDetails(currentState.playlist.playlistId));
      },
    );
  }
}
