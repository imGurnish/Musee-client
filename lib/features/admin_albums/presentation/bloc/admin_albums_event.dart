part of 'admin_albums_bloc.dart';

abstract class AdminAlbumsEvent {}

class LoadAlbums extends AdminAlbumsEvent {
  final int page;
  final int limit;
  final String? search;
  LoadAlbums({this.page = 0, this.limit = 20, this.search});
}

class CreateAlbumEvent extends AdminAlbumsEvent {
  final String title;
  final String? description;
  final List<String>? genres;
  final bool? isPublished;
  final String artistId;
  final List<int>? coverBytes;
  final String? coverFilename;
  CreateAlbumEvent({
    required this.title,
    this.description,
    this.genres,
    this.isPublished,
    required this.artistId,
    this.coverBytes,
    this.coverFilename,
  });
}

class UpdateAlbumEvent extends AdminAlbumsEvent {
  final String id;
  final String? title;
  final String? description;
  final List<String>? genres;
  final bool? isPublished;
  final List<int>? coverBytes;
  final String? coverFilename;
  UpdateAlbumEvent({
    required this.id,
    this.title,
    this.description,
    this.genres,
    this.isPublished,
    this.coverBytes,
    this.coverFilename,
  });
}

class DeleteAlbumEvent extends AdminAlbumsEvent {
  final String id;
  DeleteAlbumEvent(this.id);
}

class DeleteAlbumsEvent extends AdminAlbumsEvent {
  final List<String> ids;
  DeleteAlbumsEvent(this.ids);
}
