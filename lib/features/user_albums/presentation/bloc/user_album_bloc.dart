import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/user_albums/domain/entities/user_album.dart';
import 'package:musee/features/user_albums/domain/usecases/get_user_album.dart';

part 'user_album_event.dart';
part 'user_album_state.dart';

class UserAlbumBloc extends Bloc<UserAlbumEvent, UserAlbumState> {
  final GetUserAlbum _getAlbum;
  UserAlbumBloc(this._getAlbum) : super(const UserAlbumState.initial()) {
    on<UserAlbumLoadRequested>(_onLoad);
  }

  Future<void> _onLoad(
    UserAlbumLoadRequested event,
    Emitter<UserAlbumState> emit,
  ) async {
    emit(const UserAlbumState.loading());
    try {
      final album = await _getAlbum(
        event.albumId,
        forceRefresh: event.forceRefresh,
      );
      emit(UserAlbumState.loaded(album));
    } catch (e) {
      emit(UserAlbumState.error(e.toString()));
    }
  }
}
