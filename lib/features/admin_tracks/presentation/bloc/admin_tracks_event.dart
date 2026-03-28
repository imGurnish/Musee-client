part of 'admin_tracks_bloc.dart';

abstract class AdminTracksEvent {}

class LoadTracks extends AdminTracksEvent {
  final int page;
  final int limit;
  final String? search;

  LoadTracks({this.page = 0, this.limit = 20, this.search});
}

class CreateTrackEvent extends AdminTracksEvent {
  final String title;
  final String albumId;
  final int duration;
  final String? lyricsUrl;
  final bool? isExplicit;
  final bool? isPublished;
  final List<int> audioBytes;
  final String audioFilename;
  final List<int>? videoBytes;
  final String? videoFilename;
  final List<Map<String, String>>? artists;

  CreateTrackEvent({
    required this.title,
    required this.albumId,
    required this.duration,
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

class UpdateTrackEvent extends AdminTracksEvent {
  final String id;
  final String? title;
  final String? albumId;
  final int? duration;
  final String? lyricsUrl;
  final bool? isExplicit;
  final bool? isPublished;
  final List<int>? audioBytes;
  final String? audioFilename;
  final List<int>? videoBytes;
  final String? videoFilename;
  final List<Map<String, String>>? artists;

  UpdateTrackEvent({
    required this.id,
    this.title,
    this.albumId,
    this.duration,
    this.lyricsUrl,
    this.isExplicit,
    this.isPublished,
    this.audioBytes,
    this.audioFilename,
    this.videoBytes,
    this.videoFilename,
    this.artists,
  });
}

class DeleteTrackEvent extends AdminTracksEvent {
  final String id;
  DeleteTrackEvent(this.id);
}

class DeleteTracksEvent extends AdminTracksEvent {
  final List<String> ids;
  DeleteTracksEvent(this.ids);
}

class LinkArtistToTrackEvent extends AdminTracksEvent {
  final String trackId;
  final String artistId;
  final String role; // owner|editor|viewer
  LinkArtistToTrackEvent({
    required this.trackId,
    required this.artistId,
    required this.role,
  });
}

class UpdateTrackArtistRoleEvent extends AdminTracksEvent {
  final String trackId;
  final String artistId;
  final String role; // owner|editor|viewer
  UpdateTrackArtistRoleEvent({
    required this.trackId,
    required this.artistId,
    required this.role,
  });
}

class UnlinkArtistFromTrackEvent extends AdminTracksEvent {
  final String trackId;
  final String artistId;
  UnlinkArtistFromTrackEvent({required this.trackId, required this.artistId});
}
