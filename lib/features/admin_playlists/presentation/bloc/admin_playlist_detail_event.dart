part of 'admin_playlist_detail_bloc.dart';

abstract class AdminPlaylistDetailEvent {}

class LoadPlaylistDetails extends AdminPlaylistDetailEvent {
  final String playlistId;

  LoadPlaylistDetails(this.playlistId);
}

class SearchTracksEvent extends AdminPlaylistDetailEvent {
  final String? query;
  final int page;

  SearchTracksEvent({this.query, this.page = 0});
}

class AddTrackEvent extends AdminPlaylistDetailEvent {
  final String trackId;

  AddTrackEvent(this.trackId);
}

class RemoveTrackEvent extends AdminPlaylistDetailEvent {
  final String trackId;

  RemoveTrackEvent(this.trackId);
}
