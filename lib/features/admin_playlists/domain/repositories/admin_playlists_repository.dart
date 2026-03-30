import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/features/admin_playlists/domain/entities/playlist.dart';
import 'package:musee/features/admin_playlists/data/models/track_search_model.dart';

abstract class AdminPlaylistsRepository {
  Future<Either<Failure, Playlist>> getPlaylistDetails(String playlistId);

  Future<Either<Failure, (List<TrackSearchModel> items, int total, int page, int limit)>>
      searchTracks({
    int page = 0,
    int limit = 20,
    String? query,
  });

  Future<Either<Failure, Playlist>> addTrackToPlaylist({
    required String playlistId,
    required String trackId,
  });

  Future<Either<Failure, void>> removeTrackFromPlaylist({
    required String playlistId,
    required String trackId,
  });
}
