import 'package:bloc/bloc.dart';
import '../../domain/entities/track.dart';
import '../../domain/usecases/create_track.dart';
import '../../domain/usecases/delete_track.dart';
import '../../domain/usecases/delete_tracks.dart';
import '../../domain/usecases/list_tracks.dart';
import '../../domain/usecases/update_track.dart';
import '../../domain/usecases/link_track_artist.dart';
import '../../domain/usecases/update_track_artist_role.dart';
import '../../domain/usecases/unlink_track_artist.dart';

part 'admin_tracks_event.dart';
part 'admin_tracks_state.dart';

class AdminTracksBloc extends Bloc<AdminTracksEvent, AdminTracksState> {
  final ListTracks list;
  final CreateTrack create;
  final UpdateTrack update;
  final DeleteTrack delete;
  final DeleteTracks deleteMany;
  final LinkTrackArtist linkArtist;
  final UpdateTrackArtistRole updateArtistRole;
  final UnlinkTrackArtist unlinkArtist;

  AdminTracksBloc({
    required this.list,
    required this.create,
    required this.update,
    required this.delete,
    required this.deleteMany,
    required this.linkArtist,
    required this.updateArtistRole,
    required this.unlinkArtist,
  }) : super(const AdminTracksInitial()) {
    on<LoadTracks>(_onLoad);
    on<CreateTrackEvent>(_onCreate);
    on<UpdateTrackEvent>(_onUpdate);
    on<DeleteTrackEvent>(_onDelete);
    on<DeleteTracksEvent>(_onDeleteTracks);
    on<LinkArtistToTrackEvent>(_onLinkArtist);
    on<UpdateTrackArtistRoleEvent>(_onUpdateArtistRole);
    on<UnlinkArtistFromTrackEvent>(_onUnlinkArtist);
  }

  Future<void> _onLoad(LoadTracks event, Emitter<AdminTracksState> emit) async {
    emit(const AdminTracksLoading());
    final res = await list(
      ListTracksParams(page: event.page, limit: event.limit, q: event.search),
    );
    res.fold(
      (f) => emit(AdminTracksFailure(f.message)),
      (t) => emit(
        AdminTracksPageLoaded(
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
    CreateTrackEvent event,
    Emitter<AdminTracksState> emit,
  ) async {
    emit(const AdminTracksLoading());
    final res = await create(
      CreateTrackParams(
        title: event.title,
        albumId: event.albumId,
        duration: event.duration,
        lyricsUrl: event.lyricsUrl,
        isExplicit: event.isExplicit,
        isPublished: event.isPublished,
        audioBytes: event.audioBytes,
        audioFilename: event.audioFilename,
        videoBytes: event.videoBytes,
        videoFilename: event.videoFilename,
        artists: event.artists,
      ),
    );
    await res.fold((f) async => emit(AdminTracksFailure(f.message)), (_) async {
      final st = state;
      var page = 0, limit = 20;
      String? search;
      if (st is AdminTracksPageLoaded) {
        page = st.page;
        limit = st.limit;
        search = st.search;
      }
      final reload = await list(
        ListTracksParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminTracksFailure(f.message)),
        (t) => emit(
          AdminTracksPageLoaded(
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
    UpdateTrackEvent event,
    Emitter<AdminTracksState> emit,
  ) async {
    emit(const AdminTracksLoading());
    final res = await update(
      UpdateTrackParams(
        id: event.id,
        title: event.title,
        albumId: event.albumId,
        duration: event.duration,
        lyricsUrl: event.lyricsUrl,
        isExplicit: event.isExplicit,
        isPublished: event.isPublished,
        audioBytes: event.audioBytes,
        audioFilename: event.audioFilename,
        videoBytes: event.videoBytes,
        videoFilename: event.videoFilename,
        artists: event.artists,
      ),
    );
    await res.fold((f) async => emit(AdminTracksFailure(f.message)), (_) async {
      final st = state;
      var page = 0, limit = 20;
      String? search;
      if (st is AdminTracksPageLoaded) {
        page = st.page;
        limit = st.limit;
        search = st.search;
      }
      final reload = await list(
        ListTracksParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminTracksFailure(f.message)),
        (t) => emit(
          AdminTracksPageLoaded(
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
    DeleteTrackEvent event,
    Emitter<AdminTracksState> emit,
  ) async {
    emit(const AdminTracksLoading());
    final res = await delete(DeleteTrackParams(event.id));
    await res.fold((f) async => emit(AdminTracksFailure(f.message)), (_) async {
      final st = state;
      var page = 0, limit = 20;
      String? search;
      if (st is AdminTracksPageLoaded) {
        page = st.page;
        limit = st.limit;
        search = st.search;
      }
      final reload = await list(
        ListTracksParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminTracksFailure(f.message)),
        (t) => emit(
          AdminTracksPageLoaded(
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

  Future<void> _onDeleteTracks(
    DeleteTracksEvent event,
    Emitter<AdminTracksState> emit,
  ) async {
    emit(const AdminTracksLoading());
    final res = await deleteMany(event.ids);
    await res.fold((f) async => emit(AdminTracksFailure(f.message)), (_) async {
      final st = state;
      var page = 0, limit = 20;
      String? search;
      if (st is AdminTracksPageLoaded) {
        page = st.page;
        limit = st.limit;
        search = st.search;
      }
      final reload = await list(
        ListTracksParams(page: page, limit: limit, q: search),
      );
      reload.fold(
        (f) => emit(AdminTracksFailure(f.message)),
        (t) => emit(
          AdminTracksPageLoaded(
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

  Future<void> _reloadCurrentPage(Emitter<AdminTracksState> emit) async {
    final st = state;
    var page = 0, limit = 20;
    String? search;
    if (st is AdminTracksPageLoaded) {
      page = st.page;
      limit = st.limit;
      search = st.search;
    }
    final reload = await list(
      ListTracksParams(page: page, limit: limit, q: search),
    );
    reload.fold(
      (f) => emit(AdminTracksFailure(f.message)),
      (t) => emit(
        AdminTracksPageLoaded(
          items: t.$1,
          total: t.$2,
          page: t.$3,
          limit: t.$4,
          search: search,
        ),
      ),
    );
  }

  Future<void> _onLinkArtist(
    LinkArtistToTrackEvent event,
    Emitter<AdminTracksState> emit,
  ) async {
    emit(const AdminTracksLoading());
    final res = await linkArtist(
      LinkTrackArtistParams(
        trackId: event.trackId,
        artistId: event.artistId,
        role: event.role,
      ),
    );
    await res.fold(
      (f) async => emit(AdminTracksFailure(f.message)),
      (_) async => _reloadCurrentPage(emit),
    );
  }

  Future<void> _onUpdateArtistRole(
    UpdateTrackArtistRoleEvent event,
    Emitter<AdminTracksState> emit,
  ) async {
    emit(const AdminTracksLoading());
    final res = await updateArtistRole(
      UpdateTrackArtistRoleParams(
        trackId: event.trackId,
        artistId: event.artistId,
        role: event.role,
      ),
    );
    await res.fold(
      (f) async => emit(AdminTracksFailure(f.message)),
      (_) async => _reloadCurrentPage(emit),
    );
  }

  Future<void> _onUnlinkArtist(
    UnlinkArtistFromTrackEvent event,
    Emitter<AdminTracksState> emit,
  ) async {
    emit(const AdminTracksLoading());
    final res = await unlinkArtist(
      UnlinkTrackArtistParams(trackId: event.trackId, artistId: event.artistId),
    );
    await res.fold(
      (f) async => emit(AdminTracksFailure(f.message)),
      (_) async => _reloadCurrentPage(emit),
    );
  }
}
