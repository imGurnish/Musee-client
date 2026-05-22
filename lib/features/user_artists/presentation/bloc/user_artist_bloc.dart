import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/user_artists/domain/entities/user_artist.dart';
import 'package:musee/features/user_artists/domain/usecases/get_user_artist_albums.dart';
import 'package:musee/features/user_artists/domain/usecases/get_user_artist.dart';

part 'user_artist_event.dart';
part 'user_artist_state.dart';

class UserArtistBloc extends Bloc<UserArtistEvent, UserArtistState> {
  final GetUserArtist _getArtist;
  final GetUserArtistAlbums _getArtistAlbums;
  static const _pageSize = 20;

  UserArtistBloc(this._getArtist, this._getArtistAlbums)
    : super(const UserArtistState.initial()) {
    on<UserArtistLoadRequested>(_onLoad);
    on<UserArtistAlbumsLoadRequested>(_onLoadMore);
  }

  // ─── Initial load ──────────────────────────────────────────────────────────

  Future<void> _onLoad(
    UserArtistLoadRequested event,
    Emitter<UserArtistState> emit,
  ) async {
    emit(const UserArtistState.loading());
    try {
      // getArtist already fetches page-0 albums + singles in parallel
      // via the repository layer.
      final artist = await _getArtist(event.artistId);

      // Determine initial end conditions from the merged list sizes.
      // The repository places singles first, so we can't easily split them
      // back out here – instead the repo already fetches 20 of each, and the
      // first page counts are reflected in the combined list length.
      // We use a heuristic: if total combined < pageSize for albums or singles
      // individually we mark that side as done.  The repo fetches 20 of each;
      // if either returned fewer than _pageSize we know that side ended.
      //
      // To keep it simple and correct, we start both cursors at page 0 and
      // check pagination by counting how many of each kind are in the list.
      final singlesCount = artist.albums.where((a) => a.isSingle).length;
      final albumsCount = artist.albums.where((a) => !a.isSingle).length;

      emit(
        UserArtistState.loaded(
          artist,
          albumPage: 0,
          albumLimit: _pageSize,
          hasReachedAlbumEnd: albumsCount < _pageSize,
          singlesPage: 0,
          singlesLimit: _pageSize,
          hasReachedSinglesEnd: singlesCount < _pageSize,
        ),
      );
    } catch (e) {
      emit(UserArtistState.error(e.toString()));
    }
  }

  // ─── Load more ─────────────────────────────────────────────────────────────

  Future<void> _onLoadMore(
    UserArtistAlbumsLoadRequested event,
    Emitter<UserArtistState> emit,
  ) async {
    final artist = state.artist;
    if (artist == null || state.isLoading || state.isLoadingMore) return;
    if (state.hasReachedAllEnd) return;

    emit(state.copyWith(isLoadingMore: true, error: null));

    try {
      // Fire both requests concurrently; skip whichever side has ended.
      final futures = await Future.wait([
        // Albums page (or empty stub if already done)
        if (!state.hasReachedAlbumEnd)
          _getArtistAlbums(
            artistId: event.artistId,
            page: state.albumPage + 1,
            limit: state.albumLimit,
            singleTrack: false,
          )
        else
          Future.value((<UserArtistAlbum>[], 0, state.albumPage, state.albumLimit)),

        // Singles page (or empty stub if already done)
        if (!state.hasReachedSinglesEnd)
          _getArtistAlbums(
            artistId: event.artistId,
            page: state.singlesPage + 1,
            limit: state.singlesLimit,
            singleTrack: true,
          )
        else
          Future.value((<UserArtistAlbum>[], 0, state.singlesPage, state.singlesLimit)),
      ]);

      final albumsResult = futures[0];
      final singlesResult = futures[1];

      final newAlbums = albumsResult.$1;
      final newSingles = singlesResult.$1;

      // Merge: new singles before new albums, then append to existing list.
      final combinedAlbums = [
        ...artist.albums,
        ...newSingles,
        ...newAlbums,
      ];

      final updatedArtist = UserArtistDetail(
        artistId: artist.artistId,
        name: artist.name,
        avatarUrl: artist.avatarUrl,
        coverUrl: artist.coverUrl,
        bio: artist.bio,
        genres: artist.genres,
        monthlyListeners: artist.monthlyListeners,
        albums: combinedAlbums,
        tracks: artist.tracks,
      );

      emit(
        state.copyWith(
          isLoading: false,
          isLoadingMore: false,
          artist: updatedArtist,
          albumPage: albumsResult.$3,
          albumLimit: albumsResult.$4,
          hasReachedAlbumEnd:
              state.hasReachedAlbumEnd ||
              newAlbums.isEmpty ||
              newAlbums.length < state.albumLimit,
          singlesPage: singlesResult.$3,
          singlesLimit: singlesResult.$4,
          hasReachedSinglesEnd:
              state.hasReachedSinglesEnd ||
              newSingles.isEmpty ||
              newSingles.length < state.singlesLimit,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false, error: e.toString()));
    }
  }
}
