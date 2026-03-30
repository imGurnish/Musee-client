import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/core/usecase/usecase.dart';
import '../entities/track.dart';
import '../repository/admin_tracks_repository.dart';

class CreateTrackParams {
  final String title;
  final String albumId;
  final int duration;
  final String? externalTrackId;
  final String? language;
  final String? releaseDate;
  final String? lyricsUrl;
  final bool? isExplicit;
  final bool? isPublished;
  final List<int> audioBytes;
  final String audioFilename;
  final List<int>? videoBytes;
  final String? videoFilename;
  final List<Map<String, String>>? artists; // [{artist_id, role}]

  const CreateTrackParams({
    required this.title,
    required this.albumId,
    required this.duration,
    this.externalTrackId,
    this.language,
    this.releaseDate,
    this.lyricsUrl,
    this.isExplicit,
    this.isPublished,
    required this.audioBytes,
    required this.audioFilename,
    this.videoBytes,
    this.videoFilename,
    this.artists,
  });
}

class CreateTrack implements UseCase<Track, CreateTrackParams> {
  final AdminTracksRepository repo;
  CreateTrack(this.repo);

  @override
  Future<Either<Failure, Track>> call(CreateTrackParams params) {
    return repo.createTrack(
      title: params.title,
      albumId: params.albumId,
      duration: params.duration,
      externalTrackId: params.externalTrackId,
      language: params.language,
      releaseDate: params.releaseDate,
      lyricsUrl: params.lyricsUrl,
      isExplicit: params.isExplicit,
      isPublished: params.isPublished,
      audioBytes: params.audioBytes,
      audioFilename: params.audioFilename,
      videoBytes: params.videoBytes,
      videoFilename: params.videoFilename,
      artists: params.artists,
    );
  }
}
