import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import '../entities/track.dart';

abstract class AdminTracksRepository {
  Future<Either<Failure, (List<Track> items, int total, int page, int limit)>>
  listTracks({int page = 0, int limit = 20, String? q});

  Future<Either<Failure, Track>> getTrack(String id);

  Future<Either<Failure, Track>> createTrack({
    required String title,
    required String albumId,
    required int duration,
    String? externalTrackId,
    String? language,
    String? releaseDate,
    String? lyricsUrl,
    bool? isExplicit,
    bool? isPublished,
    required List<int> audioBytes,
    required String audioFilename,
    List<int>? videoBytes,
    String? videoFilename,
    List<Map<String, String>>? artists,
  });

  Future<Either<Failure, Track>> updateTrack({
    required String id,
    String? title,
    String? albumId,
    int? duration,
    String? externalTrackId,
    String? language,
    String? releaseDate,
    String? lyricsUrl,
    bool? isExplicit,
    bool? isPublished,
    List<int>? audioBytes,
    String? audioFilename,
    List<int>? videoBytes,
    String? videoFilename,
    List<Map<String, String>>? artists,
  });

  Future<Either<Failure, void>> deleteTrack(String id);

  // Artist management
  Future<Either<Failure, void>> linkArtistToTrack({
    required String trackId,
    required String artistId,
    required String role, // owner|editor|viewer
  });

  Future<Either<Failure, void>> updateTrackArtistRole({
    required String trackId,
    required String artistId,
    required String role, // owner|editor|viewer
  });

  Future<Either<Failure, void>> unlinkArtistFromTrack({
    required String trackId,
    required String artistId,
  });
}
