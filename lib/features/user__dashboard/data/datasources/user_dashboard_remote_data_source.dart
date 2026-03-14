import 'package:musee/core/providers/music_provider_registry.dart';
import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart';

class DashboardItemDTO extends DashboardItem {
  const DashboardItemDTO({
    required super.id,
    required super.title,
    super.coverUrl,
    super.duration,
    required super.artists,
    required super.type,
    super.trackId,
    super.albumId,
  });
}

class PagedDashboardItemsDTO extends PagedDashboardItems {
  const PagedDashboardItemsDTO({
    required super.items,
    required super.total,
    required super.page,
    required super.limit,
  });
}

abstract interface class UserDashboardRemoteDataSource {
  Future<PagedDashboardItemsDTO> getMadeForYou({int page = 0, int limit = 20});
  Future<PagedDashboardItemsDTO> getTrending({int page = 0, int limit = 20});
}

/// Dashboard data source using external (JioSaavn) API via MusicProviderRegistry.
/// "Made for you" uses new releases, "Trending" uses trending tracks.
class UserDashboardRemoteDataSourceImpl
    implements UserDashboardRemoteDataSource {
  final MusicProviderRegistry _registry;

  UserDashboardRemoteDataSourceImpl(this._registry);

  @override
  Future<PagedDashboardItemsDTO> getMadeForYou({
    int page = 0,
    int limit = 20,
  }) async {
    final albums = await _registry.getNewReleases(limitPerProvider: limit);

    final items = albums
        .map(
          (album) => DashboardItemDTO(
            id: album.prefixedId,
            albumId: album.prefixedId,
            title: album.title,
            coverUrl: album.coverUrl,
            duration: null,
            artists: album.artists
                .map(
                  (a) =>
                      DashboardArtist(artistId: a.prefixedId, name: a.name),
                )
                .toList(),
            type: DashboardItemType.album,
          ),
        )
        .toList();

    return PagedDashboardItemsDTO(
      items: items,
      total: items.length,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<PagedDashboardItemsDTO> getTrending({
    int page = 0,
    int limit = 20,
  }) async {
    final tracks = await _registry.getTrendingTracks(limitPerProvider: limit);

    final items = tracks
        .map(
          (track) => DashboardItemDTO(
            id: track.prefixedId,
            trackId: track.prefixedId,
            title: track.title,
            coverUrl: track.imageUrl,
            duration: track.durationSeconds,
            artists: track.artists
                .map(
                  (a) =>
                      DashboardArtist(artistId: a.prefixedId, name: a.name),
                )
                .toList(),
            type: DashboardItemType.track,
          ),
        )
        .toList();

    return PagedDashboardItemsDTO(
      items: items,
      total: items.length,
      page: page,
      limit: limit,
    );
  }
}
