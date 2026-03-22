import 'package:musee/core/common/widgets/loader.dart';
import 'package:musee/features/search/domain/entities/catalog_search.dart';
import 'package:musee/features/search/presentation/bloc/search_bloc.dart';
import 'package:musee/features/search/presentation/pages/search_suggestions_page.dart';
import 'package:musee/init_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:get_it/get_it.dart';

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
      context.read<SearchBloc>().add(SearchQuery(query: widget.query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 1),
    );
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
      SearchResultsLoaded(results: final results) => _buildCatalogSearchResults(
        results,
      ),
      VideosError() => _buildErrorState(),
      _ => _buildInitialState(),
    };
  }

  Widget _buildCatalogSearchResults(CatalogSearchResults results) {
    if (results.isEmpty) return _buildEmptyState();

    final top = _pickTopResult(results);

    return CustomScrollView(
      slivers: [
        _buildSearchHeader(),
        if (top != null) SliverToBoxAdapter(child: _TopResultCard(top: top)),
        if (results.tracks.isNotEmpty)
          SliverToBoxAdapter(
            child: _SectionList(
              title: 'Songs',
              children: results.tracks
                  .map((t) => _TrackTile(track: t))
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
                  .map((a) => _AlbumTile(album: a))
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
    return null;
  }

  /// Builds search results header
  Widget _buildSearchHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Search results for "${widget.query}"',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
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

  /// Navigates to search suggestions page
  void _navigateToSearchSuggestions(String currentQuery) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlocProvider(
          create: (context) => SearchBloc(serviceLocator(), serviceLocator()),
          child: SearchSuggestionsPage(query: currentQuery),
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
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
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
  const _TrackTile({required this.track});

  @override
  Widget build(BuildContext context) {
    final artistNames = track.artists
        .map((a) => a.name ?? a.artistId)
        .join(', ');

    return ListTile(
      leading: _buildLeading(),
      title: Row(
        children: [
          Expanded(
            child: Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        ],
      ),
      subtitle: Text(artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Download',
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              GetIt.I<DownloadManager>().addToQueue(track.trackId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to downloads')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Add to queue',
            icon: const Icon(Icons.queue_music_rounded),
            onPressed: () async {
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
            },
          ),
          IconButton(
            tooltip: 'Play',
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: () => _playTrack(context, artistNames),
          ),
        ],
      ),
      onTap: () => _playTrack(context, artistNames),
    );
  }

  Widget _buildLeading() {
    if (track.imageUrl != null && track.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          track.imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.music_note),
        ),
      );
    }
    return const Icon(Icons.music_note);
  }

  Future<void> _playTrack(BuildContext context, String artistNames) async {
    await showPlayerBottomSheet(
      context,
      trackId: track.trackId,
      audioUrl: null, // Let the cubit resolve it
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
    return ListTile(
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
      onTap: () {
        context.push('/artists/${artist.artistId}');
      },
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final CatalogAlbum album;
  const _AlbumTile({required this.album});

  @override
  Widget build(BuildContext context) {
    final artistNames = album.artists
        .map((a) => a.name ?? a.artistId)
        .join(', ');
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: album.coverUrl != null && album.coverUrl!.isNotEmpty
            ? Image.network(
                album.coverUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.album),
              )
            : const Icon(Icons.album),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        ],
      ),
      subtitle: Text(artistNames, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: const _TypeChip(label: 'Album'),
      onTap: () {
        context.push('/albums/${album.albumId}');
      },
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
