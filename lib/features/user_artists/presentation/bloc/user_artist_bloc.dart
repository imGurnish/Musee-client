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
  static const _albumPageSize = 20;

  UserArtistBloc(this._getArtist, this._getArtistAlbums)
    : super(const UserArtistState.initial()) {
    on<UserArtistLoadRequested>(_onLoad);
    on<UserArtistAlbumsLoadRequested>(_onLoadMoreAlbums);
  }

  Future<void> _onLoad(
    UserArtistLoadRequested event,
    Emitter<UserArtistState> emit,
  ) async {
    emit(const UserArtistState.loading());
    try {
      final artist = await _getArtist(event.artistId);
      emit(
        UserArtistState.loaded(
          artist,
          albumPage: 0,
          albumLimit: _albumPageSize,
          hasReachedAlbumEnd: artist.albums.length < _albumPageSize,
        ),
      );
    } catch (e) {
      emit(UserArtistState.error(e.toString()));
    }
  }

  Future<void> _onLoadMoreAlbums(
    UserArtistAlbumsLoadRequested event,
    Emitter<UserArtistState> emit,
  ) async {
    final artist = state.artist;
    if (artist == null || state.isLoading || state.isLoadingMore) return;
    if (state.hasReachedAlbumEnd) return;

    emit(state.copyWith(isLoadingMore: true, error: null));

    try {
      final pageData = await _getArtistAlbums(
        artistId: event.artistId,
        page: event.page,
        limit: event.limit,
      );
      final combinedAlbums = [
        ...artist.albums,
        ...pageData.$1,
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
          albumPage: pageData.$3,
          albumLimit: pageData.$4,
          hasReachedAlbumEnd: pageData.$1.isEmpty || pageData.$1.length < pageData.$4,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false, error: e.toString()));
    }
  }
}
