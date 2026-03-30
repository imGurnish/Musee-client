import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:musee/core/error/failures.dart';
import 'package:musee/features/admin_tracks/data/datasources/admin_tracks_remote_data_source.dart';
import 'package:musee/features/admin_tracks/domain/entities/track.dart';
import 'package:musee/features/admin_tracks/domain/repository/admin_tracks_repository.dart';

class AdminTracksRepositoryImpl implements AdminTracksRepository {
  final AdminTracksRemoteDataSource remote;
  AdminTracksRepositoryImpl(this.remote);

  @override
  Future<Either<Failure, (List<Track>, int, int, int)>> listTracks({
    int page = 0,
    int limit = 20,
    String? q,
  }) async {
    try {
      final r = await remote.listTracks(page: page, limit: limit, q: q);
      return right((r.$1, r.$2, r.$3, r.$4));
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Track>> getTrack(String id) async {
    try {
      final t = await remote.getTrack(id);
      return right(t);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
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
  }) async {
    try {
      final t = await remote.createTrack(
        title: title,
        albumId: albumId,
        duration: duration,
        externalTrackId: externalTrackId,
        language: language,
        releaseDate: releaseDate,
        lyricsUrl: lyricsUrl,
        isExplicit: isExplicit,
        isPublished: isPublished,
        audioBytes: Uint8List.fromList(audioBytes),
        audioFilename: audioFilename,
        videoBytes: videoBytes != null ? Uint8List.fromList(videoBytes) : null,
        videoFilename: videoFilename,
        artists: artists,
      );
      return right(t);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
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
  }) async {
    try {
      final t = await remote.updateTrack(
        id: id,
        title: title,
        albumId: albumId,
        duration: duration,
        externalTrackId: externalTrackId,
        language: language,
        releaseDate: releaseDate,
        lyricsUrl: lyricsUrl,
        isExplicit: isExplicit,
        isPublished: isPublished,
        audioBytes: audioBytes != null ? Uint8List.fromList(audioBytes) : null,
        audioFilename: audioFilename,
        videoBytes: videoBytes != null ? Uint8List.fromList(videoBytes) : null,
        videoFilename: videoFilename,
        artists: artists,
      );
      return right(t);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTrack(String id) async {
    try {
      await remote.deleteTrack(id);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTracks(List<String> ids) async {
    try {
      await remote.deleteTracks(ids);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> linkArtistToTrack({
    required String trackId,
    required String artistId,
    required String role,
  }) async {
    try {
      await remote.linkArtistToTrack(
        trackId: trackId,
        artistId: artistId,
        role: role,
      );
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateTrackArtistRole({
    required String trackId,
    required String artistId,
    required String role,
  }) async {
    try {
      await remote.updateTrackArtistRole(
        trackId: trackId,
        artistId: artistId,
        role: role,
      );
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> unlinkArtistFromTrack({
    required String trackId,
    required String artistId,
  }) async {
    try {
      await remote.unlinkArtistFromTrack(trackId: trackId, artistId: artistId);
      return right(null);
    } on DioException catch (e) {
      return left(Failure(e.message ?? 'Network error'));
    } catch (e) {
      return left(Failure(e.toString()));
    }
  }
}
