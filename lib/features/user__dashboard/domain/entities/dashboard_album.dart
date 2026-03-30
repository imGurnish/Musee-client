import 'package:equatable/equatable.dart';

enum DashboardItemType { album, track, playlist }

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
  final bool isCached;
  final String? localImagePath;

  const DashboardItem({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.duration,
    required this.artists,
    required this.type,
    this.trackId,
    this.albumId,
    this.isCached = false,
    this.localImagePath,
  });

  DashboardItem copyWith({
    String? id,
    String? title,
    String? coverUrl,
    int? duration,
    List<DashboardArtist>? artists,
    DashboardItemType? type,
    String? trackId,
    String? albumId,
    bool? isCached,
    String? localImagePath,
  }) {
    return DashboardItem(
      id: id ?? this.id,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      duration: duration ?? this.duration,
      artists: artists ?? this.artists,
      type: type ?? this.type,
      trackId: trackId ?? this.trackId,
      albumId: albumId ?? this.albumId,
      isCached: isCached ?? this.isCached,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }

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
    isCached,
    localImagePath,
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
