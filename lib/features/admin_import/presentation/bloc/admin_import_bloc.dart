// Import BLoC for state management

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:musee/core/error/app_logger.dart';
import 'package:musee/features/admin_import/data/datasources/admin_import_remote_data_source.dart';
import 'package:musee/features/admin_import/data/models/import_models.dart';

// Events
abstract class AdminImportEvent extends Equatable {
  const AdminImportEvent();

  @override
  List<Object?> get props => [];
}

class SearchTracksEvent extends AdminImportEvent {
  final String query;
  final int limit;

  const SearchTracksEvent({required this.query, this.limit = 10});

  @override
  List<Object?> get props => [query, limit];
}

class SearchAlbumsEvent extends AdminImportEvent {
  final String query;
  final int limit;

  const SearchAlbumsEvent({required this.query, this.limit = 10});

  @override
  List<Object?> get props => [query, limit];
}

class SearchArtistsEvent extends AdminImportEvent {
  final String query;
  final int limit;

  const SearchArtistsEvent({required this.query, this.limit = 10});

  @override
  List<Object?> get props => [query, limit];
}

class GetAlbumDetailsEvent extends AdminImportEvent {
  final String albumId;

  const GetAlbumDetailsEvent({required this.albumId});

  @override
  List<Object?> get props => [albumId];
}

class GetTrackDetailsEvent extends AdminImportEvent {
  final String trackId;

  const GetTrackDetailsEvent({required this.trackId});

  @override
  List<Object?> get props => [trackId];
}

class GetArtistDetailsEvent extends AdminImportEvent {
  final String artistId;

  const GetArtistDetailsEvent({required this.artistId});

  @override
  List<Object?> get props => [artistId];
}

class ImportAlbumEvent extends AdminImportEvent {
  final String jioSaavnAlbumId;
  final String artistName;
  final String? artistBio;
  final String? regionId;
  final bool isPublished;
  final bool dryRun;

  const ImportAlbumEvent({
    required this.jioSaavnAlbumId,
    required this.artistName,
    this.artistBio,
    this.regionId,
    this.isPublished = false,
    this.dryRun = false,
  });

  @override
  List<Object?> get props => [
    jioSaavnAlbumId,
    artistName,
    artistBio,
    regionId,
    isPublished,
    dryRun,
  ];
}

class ClearErrorEvent extends AdminImportEvent {
  const ClearErrorEvent();
}

// States
abstract class AdminImportState extends Equatable {
  const AdminImportState();

  @override
  List<Object?> get props => [];
}

class AdminImportInitial extends AdminImportState {
  const AdminImportInitial();
}

class AdminImportLoading extends AdminImportState {
  final String message;

  const AdminImportLoading({this.message = 'Loading...'});

  @override
  List<Object?> get props => [message];
}

class AdminImportSearchTracksSuccess extends AdminImportState {
  final List<JioTrackModel> tracks;
  final String query;

  const AdminImportSearchTracksSuccess({
    required this.tracks,
    required this.query,
  });

  @override
  List<Object?> get props => [tracks, query];
}

class AdminImportSearchAlbumsSuccess extends AdminImportState {
  final List<JioAlbumModel> albums;
  final String query;

  const AdminImportSearchAlbumsSuccess({
    required this.albums,
    required this.query,
  });

  @override
  List<Object?> get props => [albums, query];
}

class AdminImportSearchArtistsSuccess extends AdminImportState {
  final List<JioArtistModel> artists;
  final String query;

  const AdminImportSearchArtistsSuccess({
    required this.artists,
    required this.query,
  });

  @override
  List<Object?> get props => [artists, query];
}

class AdminImportTrackDetailsSuccess extends AdminImportState {
  final JioTrackModel track;

  const AdminImportTrackDetailsSuccess({required this.track});

  @override
  List<Object?> get props => [track];
}

class AdminImportAlbumDetailsSuccess extends AdminImportState {
  final JioAlbumModel album;

  const AdminImportAlbumDetailsSuccess({required this.album});

  @override
  List<Object?> get props => [album];
}

class AdminImportArtistDetailsSuccess extends AdminImportState {
  final JioArtistModel artist;

  const AdminImportArtistDetailsSuccess({required this.artist});

  @override
  List<Object?> get props => [artist];
}

class AdminImportProgress extends AdminImportState {
  final ImportProgressModel progress;
  final JioAlbumModel album;

  const AdminImportProgress({
    required this.progress,
    required this.album,
  });

  @override
  List<Object?> get props => [progress, album];
}

class AdminImportSuccess extends AdminImportState {
  final String sessionId;
  final String message;
  final Map<String, dynamic> result;

  const AdminImportSuccess({
    required this.sessionId,
    required this.message,
    required this.result,
  });

  @override
  List<Object?> get props => [sessionId, message, result];
}

class AdminImportError extends AdminImportState {
  final String message;
  final String? sessionId;
  final Map<String, dynamic>? transaction;

  const AdminImportError({
    required this.message,
    this.sessionId,
    this.transaction,
  });

  @override
  List<Object?> get props => [message, sessionId, transaction];
}

// BLoC
class AdminImportBloc extends Bloc<AdminImportEvent, AdminImportState> {
  final AdminImportRemoteDataSource _remoteDataSource;

  AdminImportBloc({required AdminImportRemoteDataSource remoteDataSource})
      : _remoteDataSource = remoteDataSource,
        super(const AdminImportInitial()) {
    on<SearchTracksEvent>(_onSearchTracks);
    on<SearchAlbumsEvent>(_onSearchAlbums);
    on<SearchArtistsEvent>(_onSearchArtists);
    on<GetTrackDetailsEvent>(_onGetTrackDetails);
    on<GetAlbumDetailsEvent>(_onGetAlbumDetails);
    on<GetArtistDetailsEvent>(_onGetArtistDetails);
    on<ImportAlbumEvent>(_onImportAlbum);
    on<ClearErrorEvent>(_onClearError);
  }

  Future<void> _onSearchTracks(
    SearchTracksEvent event,
    Emitter<AdminImportState> emit,
  ) async {
    try {
      emit(const AdminImportLoading(message: 'Searching tracks...'));

      final tracks = await _remoteDataSource.searchTracks(
        event.query,
        limit: event.limit,
      );

      emit(AdminImportSearchTracksSuccess(
        tracks: tracks,
        query: event.query,
      ));
    } catch (e) {
      appLogger.error('[ImportBloc] Search tracks failed', error: e);
      emit(AdminImportError(message: e.toString()));
    }
  }

  Future<void> _onSearchAlbums(
    SearchAlbumsEvent event,
    Emitter<AdminImportState> emit,
  ) async {
    try {
      emit(const AdminImportLoading(message: 'Searching albums...'));

      final albums = await _remoteDataSource.searchAlbums(
        event.query,
        limit: event.limit,
      );

      emit(AdminImportSearchAlbumsSuccess(
        albums: albums,
        query: event.query,
      ));
    } catch (e) {
      appLogger.error('[ImportBloc] Search albums failed', error: e);
      emit(AdminImportError(message: e.toString()));
    }
  }

  Future<void> _onSearchArtists(
    SearchArtistsEvent event,
    Emitter<AdminImportState> emit,
  ) async {
    try {
      emit(const AdminImportLoading(message: 'Searching artists...'));

      final artists = await _remoteDataSource.searchArtists(
        event.query,
        limit: event.limit,
      );

      emit(AdminImportSearchArtistsSuccess(
        artists: artists,
        query: event.query,
      ));
    } catch (e) {
      appLogger.error('[ImportBloc] Search artists failed', error: e);
      emit(AdminImportError(message: e.toString()));
    }
  }

  Future<void> _onGetTrackDetails(
    GetTrackDetailsEvent event,
    Emitter<AdminImportState> emit,
  ) async {
    try {
      emit(const AdminImportLoading(message: 'Fetching track details...'));

      final track = await _remoteDataSource.getTrackDetails(event.trackId);

      emit(AdminImportTrackDetailsSuccess(track: track));
    } catch (e) {
      appLogger.error('[ImportBloc] Get track details failed', error: e);
      emit(AdminImportError(message: e.toString()));
    }
  }

  Future<void> _onGetAlbumDetails(
    GetAlbumDetailsEvent event,
    Emitter<AdminImportState> emit,
  ) async {
    try {
      emit(const AdminImportLoading(message: 'Fetching album details...'));

      final album = await _remoteDataSource.getAlbumDetails(event.albumId);

      emit(AdminImportAlbumDetailsSuccess(album: album));
    } catch (e) {
      appLogger.error('[ImportBloc] Get album details failed', error: e);
      emit(AdminImportError(message: e.toString()));
    }
  }

  Future<void> _onGetArtistDetails(
    GetArtistDetailsEvent event,
    Emitter<AdminImportState> emit,
  ) async {
    try {
      emit(const AdminImportLoading(message: 'Fetching artist details...'));

      final artist = await _remoteDataSource.getArtistDetails(event.artistId);

      emit(AdminImportArtistDetailsSuccess(artist: artist));
    } catch (e) {
      appLogger.error('[ImportBloc] Get artist details failed', error: e);
      emit(AdminImportError(message: e.toString()));
    }
  }

  Future<void> _onImportAlbum(
    ImportAlbumEvent event,
    Emitter<AdminImportState> emit,
  ) async {
    try {
      appLogger.info(
        '[ImportBloc] Starting album import: ${event.jioSaavnAlbumId}'
        '${event.dryRun ? ' (DRY RUN)' : ''}'
      );

      emit(AdminImportLoading(
        message: event.dryRun
            ? 'Running dry run test...'
            : 'Importing album...',
      ));

      final result = await _remoteDataSource.importAlbum(
        jioSaavnAlbumId: event.jioSaavnAlbumId,
        artistName: event.artistName,
        artistBio: event.artistBio,
        regionId: event.regionId,
        isPublished: event.isPublished,
        dryRun: event.dryRun,
      );

      appLogger.info('[ImportBloc] Album import completed');

      emit(AdminImportSuccess(
        sessionId: result['sessionId'] as String? ?? '',
        message: result['message'] as String? ?? 'Import completed',
        result: result,
      ));
    } catch (e) {
      appLogger.error('[ImportBloc] Album import failed', error: e);
      emit(AdminImportError(message: e.toString()));
    }
  }

  Future<void> _onClearError(
    ClearErrorEvent event,
    Emitter<AdminImportState> emit,
  ) async {
    emit(const AdminImportInitial());
  }
}
