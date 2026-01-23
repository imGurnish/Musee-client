import 'package:equatable/equatable.dart';

enum DashboardItemType { album, track }

class DashboardItem extends Equatable {
  final String id; // albumId or trackId
  final String title;
  final String? coverUrl;
  final int? duration;
  final List<DashboardArtist> artists;
  final DashboardItemType type;

  // Track specific fields
  final String? trackId; // Explicit track ID helper
  final String? albumId; // Explicit album ID helper

  const DashboardItem({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.artists,
    required this.type,
    this.trackId,
    this.albumId,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    coverUrl,
    duration,
    artists,
    type,
    trackId,
    albumId,
  ];
}

class DashboardArtist extends Equatable {
  final String artistId;
  final String name;
  final String? avatarUrl;

  const DashboardArtist({
    required this.artistId,
    required this.name,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [artistId, name, avatarUrl];
}

class PagedDashboardItems extends Equatable {
  final List<DashboardItem> items;
  final int total;
  final int page;
  final int limit;

  const PagedDashboardItems({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  @override
  List<Object?> get props => [items, total, page, limit];
}
