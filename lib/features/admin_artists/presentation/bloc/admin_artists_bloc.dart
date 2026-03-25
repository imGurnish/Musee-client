import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/admin_artists/domain/entities/artist.dart';
import 'package:musee/features/admin_artists/domain/usecases/create_artist.dart';
import 'package:musee/features/admin_artists/domain/usecases/delete_artist.dart';
import 'package:musee/features/admin_artists/domain/usecases/delete_artists.dart';
import 'package:musee/features/admin_artists/domain/usecases/list_artists.dart';
import 'package:musee/features/admin_artists/domain/usecases/update_artist.dart';

part 'admin_artists_event.dart';
part 'admin_artists_state.dart';

class AdminArtistsBloc extends Bloc<AdminArtistsEvent, AdminArtistsState> {
  final ListArtists _list;
  final CreateArtist _create;
  final UpdateArtist _update;
  final DeleteArtist _delete;
  final DeleteArtists _deleteMany;

  AdminArtistsBloc({
    required ListArtists list,
    required CreateArtist create,
    required UpdateArtist update,
    required DeleteArtist delete,
    required DeleteArtists deleteMany,
  }) : _list = list,
       _create = create,
       _update = update,
       _delete = delete,
       _deleteMany = deleteMany,
       super(const AdminArtistsInitial()) {
    on<LoadArtists>(_onLoad);
    on<CreateArtistEvent>(_onCreate);
    on<UpdateArtistEvent>(_onUpdate);
    on<DeleteArtistEvent>(_onDelete);
    on<DeleteArtistsEvent>(_onDeleteArtists);
  }

  Future<void> _onLoad(
    LoadArtists event,
    Emitter<AdminArtistsState> emit,
  ) async {
    emit(const AdminArtistsLoading());
    final res = await _list(
      ListArtistsParams(page: event.page, limit: event.limit, q: event.search),
    );
    res.fold((f) => emit(AdminArtistsFailure(f.message)), (t) {
      emit(
        AdminArtistsPageLoaded(
          items: t.$1,
          total: t.$2,
          page: t.$3,
          limit: t.$4,
          search: event.search,
        ),
      );
    });
  }

  Future<void> _onCreate(
    CreateArtistEvent event,
    Emitter<AdminArtistsState> emit,
  ) async {
    emit(const AdminArtistsLoading());
    final res = await _create(
      CreateArtistParams(
        artistId: event.artistId,
        name: event.name,
        email: event.email,
        bio: event.bio,
        coverBytes: event.coverBytes,
        coverFilename: event.coverFilename,
        avatarBytes: event.avatarBytes,
        avatarFilename: event.avatarFilename,
        genres: event.genres,
        debutYear: event.debutYear,
        isVerified: event.isVerified,
        socialLinks: event.socialLinks,
        monthlyListeners: event.monthlyListeners,
        regionId: event.regionId,
        dateOfBirth: event.dateOfBirth,
      ),
    );
    await res.fold((f) async => emit(AdminArtistsFailure(f.message)), (
      _,
    ) async {
      final stateBefore = state;
      int page = 0, limit = 20;
      String? search;
      if (stateBefore is AdminArtistsPageLoaded) {
        page = stateBefore.page;
        limit = stateBefore.limit;
        search = stateBefore.search;
      }
      final reload = await _list(
        ListArtistsParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminArtistsFailure(f.message)),
        (t) => emit(
          AdminArtistsPageLoaded(
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
    UpdateArtistEvent event,
    Emitter<AdminArtistsState> emit,
  ) async {
    emit(const AdminArtistsLoading());
    final res = await _update(
      UpdateArtistParams(
        id: event.id,
        bio: event.bio,
        coverUrl: event.coverUrl,
        coverBytes: event.coverBytes,
        coverFilename: event.coverFilename,
        genres: event.genres,
        debutYear: event.debutYear,
        isVerified: event.isVerified,
        socialLinks: event.socialLinks,
        monthlyListeners: event.monthlyListeners,
        regionId: event.regionId,
        dateOfBirth: event.dateOfBirth,
      ),
    );
    await res.fold((f) async => emit(AdminArtistsFailure(f.message)), (
      _,
    ) async {
      final stateBefore = state;
      int page = 0, limit = 20;
      String? search;
      if (stateBefore is AdminArtistsPageLoaded) {
        page = stateBefore.page;
        limit = stateBefore.limit;
        search = stateBefore.search;
      }
      final reload = await _list(
        ListArtistsParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminArtistsFailure(f.message)),
        (t) => emit(
          AdminArtistsPageLoaded(
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
    DeleteArtistEvent event,
    Emitter<AdminArtistsState> emit,
  ) async {
    emit(const AdminArtistsLoading());
    final res = await _delete(event.id);
    await res.fold((f) async => emit(AdminArtistsFailure(f.message)), (
      _,
    ) async {
      final stateBefore = state;
      int page = 0, limit = 20;
      String? search;
      if (stateBefore is AdminArtistsPageLoaded) {
        page = stateBefore.page;
        limit = stateBefore.limit;
        search = stateBefore.search;
      }
      final reload = await _list(
        ListArtistsParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminArtistsFailure(f.message)),
        (t) => emit(
          AdminArtistsPageLoaded(
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

  Future<void> _onDeleteArtists(
    DeleteArtistsEvent event,
    Emitter<AdminArtistsState> emit,
  ) async {
    emit(const AdminArtistsLoading());
    final res = await _deleteMany(event.ids);
    await res.fold((f) async => emit(AdminArtistsFailure(f.message)), (
      _,
    ) async {
      final stateBefore = state;
      int page = 0, limit = 20;
      String? search;
      if (stateBefore is AdminArtistsPageLoaded) {
        page = stateBefore.page;
        limit = stateBefore.limit;
        search = stateBefore.search;
      }
      final reload = await _list(
        ListArtistsParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminArtistsFailure(f.message)),
        (t) => emit(
          AdminArtistsPageLoaded(
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
