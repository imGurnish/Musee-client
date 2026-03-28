import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/admin_albums/domain/entities/album.dart';
import 'package:musee/features/admin_albums/domain/usecases/create_album.dart';
import 'package:musee/features/admin_albums/domain/usecases/delete_album.dart';
import 'package:musee/features/admin_albums/domain/usecases/delete_albums.dart';
import 'package:musee/features/admin_albums/domain/usecases/list_albums.dart';
import 'package:musee/features/admin_albums/domain/usecases/update_album.dart';

part 'admin_albums_event.dart';
part 'admin_albums_state.dart';

class AdminAlbumsBloc extends Bloc<AdminAlbumsEvent, AdminAlbumsState> {
  final ListAlbums _list;
  final CreateAlbum _create;
  final UpdateAlbum _update;
  final DeleteAlbum _delete;
  final DeleteAlbums _deleteMany;

  AdminAlbumsBloc({
    required ListAlbums list,
    required CreateAlbum create,
    required UpdateAlbum update,
    required DeleteAlbum delete,
    required DeleteAlbums deleteMany,
  }) : _list = list,
       _create = create,
       _update = update,
       _delete = delete,
       _deleteMany = deleteMany,
       super(const AdminAlbumsInitial()) {
    on<LoadAlbums>(_onLoad);
    on<CreateAlbumEvent>(_onCreate);
    on<UpdateAlbumEvent>(_onUpdate);
    on<DeleteAlbumEvent>(_onDelete);
    on<DeleteAlbumsEvent>(_onDeleteAlbums);
  }

  Future<void> _onLoad(LoadAlbums event, Emitter<AdminAlbumsState> emit) async {
    emit(const AdminAlbumsLoading());
    final res = await _list(
      ListAlbumsParams(page: event.page, limit: event.limit, q: event.search),
    );
    res.fold(
      (f) => emit(AdminAlbumsFailure(f.message)),
      (t) => emit(
        AdminAlbumsPageLoaded(
          items: t.$1,
          total: t.$2,
          page: t.$3,
          limit: t.$4,
          search: event.search,
        ),
      ),
    );
  }

  Future<void> _onCreate(
    CreateAlbumEvent event,
    Emitter<AdminAlbumsState> emit,
  ) async {
    emit(const AdminAlbumsLoading());
    final res = await _create(
      CreateAlbumParams(
        title: event.title,
        description: event.description,
        genres: event.genres,
        isPublished: event.isPublished,
        artistId: event.artistId,
        coverBytes: event.coverBytes,
        coverFilename: event.coverFilename,
      ),
    );
    await res.fold((f) async => emit(AdminAlbumsFailure(f.message)), (_) async {
      final st = state;
      var page = 0, limit = 20;
      String? search;
      if (st is AdminAlbumsPageLoaded) {
        page = st.page;
        limit = st.limit;
        search = st.search;
      }
      final reload = await _list(
        ListAlbumsParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminAlbumsFailure(f.message)),
        (t) => emit(
          AdminAlbumsPageLoaded(
            items: t.$1,
            total: t.$2,
            page: t.$3,
            limit: t.$4,
            search: search,
          ),
        ),
      );
    });
  }

  Future<void> _onUpdate(
    UpdateAlbumEvent event,
    Emitter<AdminAlbumsState> emit,
  ) async {
    emit(const AdminAlbumsLoading());
    final res = await _update(
      UpdateAlbumParams(
        id: event.id,
        title: event.title,
        description: event.description,
        genres: event.genres,
        isPublished: event.isPublished,
        coverBytes: event.coverBytes,
        coverFilename: event.coverFilename,
      ),
    );
    await res.fold((f) async => emit(AdminAlbumsFailure(f.message)), (_) async {
      final st = state;
      var page = 0, limit = 20;
      String? search;
      if (st is AdminAlbumsPageLoaded) {
        page = st.page;
        limit = st.limit;
        search = st.search;
      }
      final reload = await _list(
        ListAlbumsParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminAlbumsFailure(f.message)),
        (t) => emit(
          AdminAlbumsPageLoaded(
            items: t.$1,
            total: t.$2,
            page: t.$3,
            limit: t.$4,
            search: search,
          ),
        ),
      );
    });
  }

  Future<void> _onDelete(
    DeleteAlbumEvent event,
    Emitter<AdminAlbumsState> emit,
  ) async {
    emit(const AdminAlbumsLoading());
    final res = await _delete(event.id);
    await res.fold((f) async => emit(AdminAlbumsFailure(f.message)), (_) async {
      final st = state;
      var page = 0, limit = 20;
      String? search;
      if (st is AdminAlbumsPageLoaded) {
        page = st.page;
        limit = st.limit;
        search = st.search;
      }
      final reload = await _list(
        ListAlbumsParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminAlbumsFailure(f.message)),
        (t) => emit(
          AdminAlbumsPageLoaded(
            items: t.$1,
            total: t.$2,
            page: t.$3,
            limit: t.$4,
            search: search,
          ),
        ),
      );
    });
  }

  Future<void> _onDeleteAlbums(
    DeleteAlbumsEvent event,
    Emitter<AdminAlbumsState> emit,
  ) async {
    emit(const AdminAlbumsLoading());
    final res = await _deleteMany(event.ids);
    await res.fold((f) async => emit(AdminAlbumsFailure(f.message)), (_) async {
      final st = state;
      var page = 0, limit = 20;
      String? search;
      if (st is AdminAlbumsPageLoaded) {
        page = st.page;
        limit = st.limit;
        search = st.search;
      }
      final reload = await _list(
        ListAlbumsParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminAlbumsFailure(f.message)),
        (t) => emit(
          AdminAlbumsPageLoaded(
            items: t.$1,
            total: t.$2,
            page: t.$3,
            limit: t.$4,
            search: search,
          ),
        ),
      );
    });
  }
}
