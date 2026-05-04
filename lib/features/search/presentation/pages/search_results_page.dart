import 'package:musee/core/common/widgets/loader.dart';
import 'package:musee/features/search/domain/entities/catalog_search.dart';
import 'package:musee/features/search/presentation/bloc/search_bloc.dart';
import 'package:musee/features/search/presentation/pages/search_suggestions_page.dart';
import 'package:musee/init_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/features/search/data/services/search_recents_service.dart';
import 'package:musee/features/search/domain/entities/search_recent_item.dart';

import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';

/// Search results page displaying search results grouped by extractors
/// Features horizontal scrollable sections for each platform (YouTube, etc.)
class SearchResultsPage extends StatefulWidget {
  final String query;

  const SearchResultsPage({super.key, required this.query});

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _triggerSearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Triggers search when page loads
  void _triggerSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<SearchBloc>().add(SearchQuery(query: widget.query));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  /// Builds app bar with search field
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: _buildSearchField(),
    );
  }

  /// Builds search input field
  Widget _buildSearchField() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextField(
        controller: _searchController,
        maxLines: 1,
        readOnly: true,
        style: const TextStyle(fontSize: 16),
        decoration: _buildSearchInputDecoration(),
        onTap: () => _navigateToSearchSuggestions(_searchController.text),
      ),
    );
  }

  /// Creates search field decoration
  InputDecoration _buildSearchInputDecoration() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: 16.0,
      ),
      filled: true,
      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
      hintText: 'Search for videos...',
      hintStyle: TextStyle(
        color: isDark ? Colors.grey[400] : Colors.grey[600],
        fontSize: 16,
      ),
      border: _buildOutlineInputBorder(),
      enabledBorder: _buildOutlineInputBorder(),
      focusedBorder: _buildOutlineInputBorder(borderColor: colorScheme.primary),
      prefixIcon: Icon(
        Icons.search,
        size: 20,
        color: isDark ? Colors.grey[400] : Colors.grey[600],
      ),
    );
  }

  /// Creates consistent outline input border
  OutlineInputBorder _buildOutlineInputBorder({Color? borderColor}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(24.0),
      borderSide: borderColor != null
          ? BorderSide(color: borderColor, width: 2)
          : BorderSide.none,
    );
  }

  /// Builds main body with BLoC consumer
  Widget _buildBody() {
    return BlocConsumer<SearchBloc, SearchState>(
      listener: _handleStateChanges,
      builder: _buildStateBasedContent,
    );
  }

  /// Handles state changes and shows snackbars for errors
  void _handleStateChanges(BuildContext context, SearchState state) {
    if (state is VideosError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  /// Builds content based on current state
  Widget _buildStateBasedContent(BuildContext context, SearchState state) {
    return switch (state) {
      SearchQueryLoading() => const Loader(),
      SearchResultsLoaded(
        results: final results,
        cachedTrackIds: final cachedTrackIds,
        cachedAlbumIds: final cachedAlbumIds,
        cachedPlaylistIds: final cachedPlaylistIds,
        fromOfflineCache: final fromOfflineCache,
      ) =>
        _buildCatalogSearchResults(
          results,
          cachedTrackIds: cachedTrackIds,
          cachedAlbumIds: cachedAlbumIds,
          cachedPlaylistIds: cachedPlaylistIds,
          fromOfflineCache: fromOfflineCache,
        ),
      VideosError() => _buildErrorState(),
      _ => _buildInitialState(),
    };
  }

  Widget _buildCatalogSearchResults(
    CatalogSearchResults results, {
    required Set<String> cachedTrackIds,
    required Set<String> cachedAlbumIds,
    required Set<String> cachedPlaylistIds,
    required bool fromOfflineCache,
  }) {
    if (results.isEmpty) return _buildEmptyState();

    final top = _pickTopResult(results);

    return CustomScrollView(
      slivers: [
        if (fromOfflineCache)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _OfflineSearchBanner(),
            ),
          ),
        _buildSearchHeader(results),
        if (top != null) SliverToBoxAdapter(child: _TopResultCard(top: top)),
        if (results.tracks.isNotEmpty)
          SliverToBoxAdapter(
            child: _SectionList(
              title: 'Songs',
              children: results.tracks
                  .map(
                    (t) => _TrackTile(
                      track: t,
                      isCached: cachedTrackIds.contains(t.trackId),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (results.artists.isNotEmpty)
          SliverToBoxAdapter(
            child: _SectionList(
              title: 'Artists',
              children: results.artists
                  .map((a) => _ArtistTile(artist: a))
                  .toList(),
            ),
          ),
        if (results.albums.isNotEmpty)
          SliverToBoxAdapter(
            child: _SectionList(
              title: 'Albums',
              children: results.albums
                  .map(
                    (a) => _AlbumTile(
                      album: a,
                      isCached: cachedAlbumIds.contains(a.albumId),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (results.playlists.isNotEmpty)
          SliverToBoxAdapter(
            child: _SectionList(
              title: 'Playlists',
              children: results.playlists
                  .map(
                    (p) => _PlaylistTile(
                      playlist: p,
                      isCached: cachedPlaylistIds.contains(p.playlistId),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Object? _pickTopResult(CatalogSearchResults r) {
    // Prefer artist, then track, then album
    if (r.artists.isNotEmpty) return r.artists.first;
    if (r.tracks.isNotEmpty) return r.tracks.first;
    if (r.albums.isNotEmpty) return r.albums.first;
    if (r.playlists.isNotEmpty) return r.playlists.first;
    return null;
  }

  /// Builds search results header
  Widget _buildSearchHeader(CatalogSearchResults results) {
    final totalCount =
        results.tracks.length +
        results.artists.length +
        results.albums.length +
        results.playlists.length;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Search results for "${widget.query}"',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '$totalCount result${totalCount == 1 ? '' : 's'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // legacy section removed

  /// Builds empty state when no results found
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found for "${widget.query}"',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try searching with different keywords',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds error state
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please try again later',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _triggerSearch, child: const Text('Retry')),
        ],
      ),
    );
  }

  /// Builds initial state
  Widget _buildInitialState() {
    return const Center(child: Loader());
  }

  /// Opens the suggestions overlay. When the user submits a new query the
  /// overlay pops and returns the query string; we then push a fresh results
  /// page on top so results stack cleanly without suggestions in between.
  Future<void> _navigateToSearchSuggestions(String currentQuery) async {
    final newQuery = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => BlocProvider(
          create: (_) => SearchBloc(serviceLocator(), serviceLocator()),
          child: SearchSuggestionsPage(query: currentQuery),
        ),
      ),
    );

    if (!mounted || newQuery == null || newQuery.trim().isEmpty) return;

    // Push a new results page on top — back button returns to this page.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider(
          create: (_) => SearchBloc(serviceLocator(), serviceLocator()),
          child: SearchResultsPage(query: newQuery.trim()),
        ),
      ),
    );
  }
}

/// Section wrapper
class _SectionList extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionList({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _TopResultCard extends StatelessWidget {
  final Object top; // CatalogArtist | CatalogTrack | CatalogAlbum
  const _TopResultCard({required this.top});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _artwork(context),
            const SizedBox(width: 16),
            Expanded(child: _info(context)),
          ],
        ),
      ),
    );
  }

  Widget _artwork(BuildContext context) {
    final double size = 96;
    String? imageUrl;
    IconData fallback = Icons.music_note;
    if (top is CatalogAlbum) {
      imageUrl = (top as CatalogAlbum).coverUrl;
      fallback = Icons.album;
    } else if (top is CatalogArtist) {
      imageUrl = (top as CatalogArtist).avatarUrl;
      fallback = Icons.person;
    } else if (top is CatalogPlaylist) {
      imageUrl = (top as CatalogPlaylist).coverUrl;
      fallback = Icons.queue_music_rounded;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover)
            : Icon(fallback, size: 48),
      ),
    );
  }

  Widget _info(BuildContext context) {
    final theme = Theme.of(context);
    String title;
    String subtitle;
    if (top is CatalogArtist) {
      final a = top as CatalogArtist;
      title = a.name ?? 'Artist';
      subtitle = 'Artist';
    } else if (top is CatalogTrack) {
      final t = top as CatalogTrack;
      title = t.title;
      final artistNames = t.artists.map((a) => a.name ?? a.artistId).join(', ');
      subtitle = 'Song • $artistNames';
    } else if (top is CatalogPlaylist) {
      final p = top as CatalogPlaylist;
      title = p.name;
      subtitle = p.creatorName?.isNotEmpty == true
          ? 'Playlist • ${p.creatorName}'
          : 'Playlist';
    } else {
      final a = top as CatalogAlbum;
      title = a.title;
      final artistNames = a.artists.map((x) => x.name ?? x.artistId).join(', ');
      subtitle = 'Album • $artistNames';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TrackTile extends StatelessWidget {
  final CatalogTrack track;
  final bool isCached;
  const _TrackTile({required this.track, required this.isCached});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artistNames = track.artists
        .map((a) => a.name ?? a.artistId)
        .join(', ');
    final durationLabel = _formatDuration(track.duration);

    return _ResultTileContainer(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _playTrack(context, artistNames),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            children: [
              _TrackArtwork(track: track, isCached: isCached),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$artistNames${durationLabel == null ? '' : ' • $durationLabel'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz_rounded),
                onPressed: () => _showTrackActionsSheet(context, artistNames),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTrackActionsSheet(
    BuildContext context,
    String artistNames,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Play now'),
              onTap: () => Navigator.pop(context, 'play'),
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to queue'),
              onTap: () => Navigator.pop(context, 'queue'),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download'),
              onTap: () => Navigator.pop(context, 'download'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || action == null) return;
    await _handleTrackAction(context, action, artistNames);
  }

  Future<void> _handleTrackAction(
    BuildContext context,
    String action,
    String artistNames,
  ) async {
    if (action == 'play') {
      await _playTrack(context, artistNames);
      return;
    }

    if (action == 'download') {
      GetIt.I<DownloadManager>().addToQueue(track.trackId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to downloads')));
      }
      return;
    }

    if (action == 'queue') {
      final item = QueueItem(
        trackId: track.trackId,
        title: track.title,
        artist: artistNames,
        album: null,
        imageUrl: track.imageUrl,
        durationSeconds: track.duration,
      );
      await GetIt.I<PlayerCubit>().addToQueue([item]);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Added to queue')));
      }
    }
  }

  String? _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return null;
    final m = seconds ~/ 60;
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _playTrack(BuildContext context, String artistNames) async {
    await GetIt.I<SearchRecentsService>().addRecent(
      SearchRecentItem(
        type: SearchRecentType.track,
        id: track.trackId,
        title: track.title,
        subtitle: artistNames,
        imageUrl: track.imageUrl,
        updatedAt: DateTime.now(),
      ),
    );

    await showPlayerBottomSheet(
      context,
      trackId: track.trackId,
      audioUrl: null,
      title: track.title,
      artist: artistNames,
      imageUrl: track.imageUrl,
    );
  }
}

class _ArtistTile extends StatelessWidget {
  final CatalogArtist artist;
  const _ArtistTile({required this.artist});

  @override
  Widget build(BuildContext context) {
    return _ResultTileContainer(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: artist.avatarUrl != null
              ? NetworkImage(artist.avatarUrl!)
              : null,
          child: artist.avatarUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                artist.name ?? 'Artist',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: const _TypeChip(label: 'Artist'),
        onTap: () async {
          await GetIt.I<SearchRecentsService>().addRecent(
            SearchRecentItem(
              type: SearchRecentType.artist,
              id: artist.artistId,
              title: artist.name ?? 'Artist',
              subtitle: 'Artist',
              imageUrl: artist.avatarUrl,
              updatedAt: DateTime.now(),
            ),
          );
          context.push('/artists/${artist.artistId}');
        },
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final CatalogAlbum album;
  final bool isCached;
  const _AlbumTile({required this.album, required this.isCached});

  @override
  Widget build(BuildContext context) {
    final artistNames = album.artists
        .map((a) => a.name ?? a.artistId)
        .join(', ');

    return _ResultTileContainer(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await _saveAlbumRecent();
          if (!context.mounted) return;
          context.push('/albums/${album.albumId}');
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            children: [
              _AlbumArtwork(album: album, isCached: isCached),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      album.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      artistNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'More',
                icon: const Icon(Icons.more_horiz_rounded),
                onPressed: () => _showAlbumActionsSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAlbumActionsSheet(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.album_rounded),
              title: const Text('Open album'),
              onTap: () => Navigator.pop(context, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.queue_music_rounded),
              title: const Text('Add to queue'),
              onTap: () => Navigator.pop(context, 'queue'),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download'),
              onTap: () => Navigator.pop(context, 'download'),
            ),
          ],
        );
      },
    );

    if (!context.mounted || action == null) return;
    _handleAlbumAction(context, action);
  }

  void _handleAlbumAction(BuildContext context, String action) {
    if (action == 'open') {
      _saveAlbumRecent();
      context.push('/albums/${album.albumId}');
      return;
    }

    if (action == 'queue') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add to queue is available in album view'),
        ),
      );
      return;
    }

    if (action == 'download') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download is available in album view')),
      );
    }
  }

  Future<void> _saveAlbumRecent() {
    return GetIt.I<SearchRecentsService>().addRecent(
      SearchRecentItem(
        type: SearchRecentType.album,
        id: album.albumId,
        title: album.title,
        subtitle: album.artists.map((a) => a.name ?? a.artistId).join(', '),
        imageUrl: album.coverUrl,
        updatedAt: DateTime.now(),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final CatalogPlaylist playlist;
  final bool isCached;
  const _PlaylistTile({required this.playlist, required this.isCached});

  @override
  Widget build(BuildContext context) {
    final subtitle = playlist.creatorName?.isNotEmpty == true
        ? playlist.creatorName!
        : 'Playlist';

    return _ResultTileContainer(
      child: ListTile(
        leading: _PlaylistArtwork(playlist: playlist, isCached: isCached),
        title: Text(
          playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const _TypeChip(label: 'Playlist'),
        onTap: () async {
          await GetIt.I<SearchRecentsService>().addRecent(
            SearchRecentItem(
              type: SearchRecentType.playlist,
              id: playlist.playlistId,
              title: playlist.name,
              subtitle: subtitle,
              imageUrl: playlist.coverUrl,
              updatedAt: DateTime.now(),
            ),
          );
          context.push('/playlists/${playlist.playlistId}');
        },
      ),
    );
  }
}

class _ResultTileContainer extends StatelessWidget {
  final Widget child;
  const _ResultTileContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.48,
        ),
        borderRadius: BorderRadius.circular(14),
        child: child,
      ),
    );
  }
}

class _ArtworkCacheBadge extends StatelessWidget {
  final bool visible;
  const _ArtworkCacheBadge({required this.visible});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    return Positioned(
      right: -2,
      bottom: -2,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(
            Icons.cloud_done_rounded,
            size: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

class _TrackArtwork extends StatelessWidget {
  final CatalogTrack track;
  final bool isCached;
  const _TrackArtwork({required this.track, required this.isCached});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: track.imageUrl != null && track.imageUrl!.isNotEmpty
                  ? Image.network(
                      track.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.music_note_rounded),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.music_note_rounded),
                    ),
            ),
          ),
          _ArtworkCacheBadge(visible: isCached),
        ],
      ),
    );
  }
}

class _AlbumArtwork extends StatelessWidget {
  final CatalogAlbum album;
  final bool isCached;
  const _AlbumArtwork({required this.album, required this.isCached});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: album.coverUrl != null && album.coverUrl!.isNotEmpty
                  ? Image.network(
                      album.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.album_rounded),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.album_rounded),
                    ),
            ),
          ),
          _ArtworkCacheBadge(visible: isCached),
        ],
      ),
    );
  }
}

class _PlaylistArtwork extends StatelessWidget {
  final CatalogPlaylist playlist;
  final bool isCached;
  const _PlaylistArtwork({required this.playlist, required this.isCached});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 56,
              child: playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty
                  ? Image.network(
                      playlist.coverUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.queue_music_rounded),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.queue_music_rounded),
                    ),
            ),
          ),
          _ArtworkCacheBadge(visible: isCached),
        ],
      ),
    );
  }
}

class _OfflineSearchBanner extends StatelessWidget {
  const _OfflineSearchBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 18,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.storage_rounded,
            size: 16,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ],
      ),
    );
  }
}

// Fetch methods removed as they are now handled by PlayerCubit

class _TypeChip extends StatelessWidget {
  final String label;
  const _TypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(96),
        ),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
