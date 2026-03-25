import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/exceptions.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/features/admin_playlists/data/datasources/admin_playlists_remote_data_source.dart';
import 'package:musee/features/admin_playlists/data/models/track_search_model.dart';
import 'package:musee/features/admin_playlists/domain/entities/playlist.dart';
import 'package:musee/features/admin_playlists/domain/repositories/admin_playlists_repository.dart';

class AdminPlaylistsRepositoryImpl implements AdminPlaylistsRepository {
  final AdminPlaylistsRemoteDataSource remoteDataSource;

  AdminPlaylistsRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Playlist>> getPlaylistDetails(String playlistId) async {
    try {
      final result = await remoteDataSource.getPlaylistDetails(playlistId);
      return Right(result);
    } on ServerException catch (e) {
      return Left(Failure(e.message));
    }
  }

  @override
  Future<Either<Failure, (List<TrackSearchModel>, int, int, int)>> searchTracks({
    int page = 0,
    int limit = 20,
    String? query,
  }) async {
    try {
      final (items, total) = await remoteDataSource.searchTracks(
        page: page,
        limit: limit,
        query: query,
      );
      return Right((items, total, page, limit));
    } on ServerException catch (e) {
      return Left(Failure(e.message));
    }
  }

  @override
  Future<Either<Failure, Playlist>> addTrackToPlaylist({
    required String playlistId,
    required String trackId,
  }) async {
    try {
      final result = await remoteDataSource.addTrackToPlaylist(
        playlistId: playlistId,
        trackId: trackId,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(Failure(e.message));
    }
  }

  @override
  Future<Either<Failure, void>> removeTrackFromPlaylist({
    required String playlistId,
    required String trackId,
  }) async {
    try {
      await remoteDataSource.removeTrackFromPlaylist(
        playlistId: playlistId,
        trackId: trackId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(Failure(e.message));
    }
  }
}
