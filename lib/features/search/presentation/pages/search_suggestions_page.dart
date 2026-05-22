import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/init_dependencies.dart';

import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';

import 'package:musee/features/search/presentation/bloc/search_bloc.dart';
import 'package:musee/features/search/data/services/search_recents_service.dart';
import 'package:musee/features/search/domain/entities/search_recent_item.dart';
import 'package:musee/features/search/domain/entities/catalog_search.dart';

/// Spotify-Style Single-Step Search Page that allows users to instantly search
/// the catalog as they type, with filter chips and endless scrolling lazy loading.
class SearchSuggestionsPage extends StatefulWidget {
  final String? query;

  const SearchSuggestionsPage({super.key, this.query});

  @override
  State<SearchSuggestionsPage> createState() => _SearchSuggestionsPageState();
}

class _SearchSuggestionsPageState extends State<SearchSuggestionsPage> {
  late final TextEditingController _searchController;
  late final SearchRecentsService _recentsService;
  late final ScrollController _scrollController;
  
  List<SearchRecentItem> _recents = const <SearchRecentItem>[];
  bool _isLoadingRecents = false;
  
  Timer? _debounceTimer;
  String? _selectedType; // null = All, 'track' = Songs, 'artist' = Artists, 'album' = Albums, 'playlist' = Playlists

  final List<Map<String, dynamic>> _filters = [
    {'label': 'All', 'type': null},
    {'label': 'Songs', 'type': 'track'},
    {'label': 'Artists', 'type': 'artist'},
    {'label': 'Albums', 'type': 'album'},
    {'label': 'Playlists', 'type': 'playlist'},
  ];

  @override
  void initState() {
    super.initState();
    _recentsService = serviceLocator<SearchRecentsService>();
    _searchController = TextEditingController(text: widget.query);
    _scrollController = ScrollController()..addListener(_onScroll);
    
    _setupSearchControllerListener();
    _initializeWithQuery();
    _loadRecents();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    // Trigger when we are within 200 pixels of the bottom
    if (maxScroll - currentScroll <= 200) {
      final state = context.read<SearchBloc>().state;
      if (state is SearchResultsLoaded &&
          !state.hasReachedMax &&
          !state.isFetchingMore &&
          _selectedType != null) {
        context.read<SearchBloc>().add(SearchQuery(
          query: _searchController.text.trim(),
          type: _selectedType,
          isLoadMore: true,
        ));
      }
    }
  }

  /// Sets up listener for search controller to update UI clear button
  void _setupSearchControllerListener() {
    _searchController.addListener(() {
      setState(() {});
    });
  }

  /// Initializes page with existing query if provided
  void _initializeWithQuery() {
    if (widget.query?.isNotEmpty == true) {
      _triggerSearch(widget.query!);
    }
  }

  /// Triggers a search query event
  void _triggerSearch(String query) {
    context.read<SearchBloc>().add(SearchQuery(
      query: query.trim(),
      type: _selectedType,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  /// Builds app bar with search field
  PreferredSizeWidget _buildAppBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 16,
      title: Row(
        children: [
          Expanded(child: _buildSearchField()),
          const SizedBox(width: 8),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(128),
              shape: BoxShape.circle,
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(128),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.mic, size: 20),
              color: colorScheme.onSurfaceVariant,
              tooltip: 'Voice Search',
              padding: EdgeInsets.zero,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Coming Soon'),
                    content: const Text('Voice search will be available in a future update!'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds search input field with proper styling
  Widget _buildSearchField() {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        maxLines: 1,
        autofocus: true,
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: _buildSearchInputDecoration(),
        onChanged: _handleSearchTextChanged,
        onSubmitted: _handleSearchSubmitted,
      ),
    );
  }

  /// Creates search field decoration with clear button
  InputDecoration _buildSearchInputDecoration() {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(
        vertical: 8.0,
        horizontal: 16.0,
      ),
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withAlpha(128),
      hintText: 'Search songs, albums, artists, playlists',
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
      border: _buildOutlineInputBorder(
        borderColor: colorScheme.outlineVariant.withAlpha(128),
        width: 1,
      ),
      enabledBorder: _buildOutlineInputBorder(
        borderColor: colorScheme.outlineVariant.withAlpha(128),
        width: 1,
      ),
      focusedBorder: _buildOutlineInputBorder(
        borderColor: colorScheme.primary,
        width: 2,
      ),
      prefixIcon: Icon(
        Icons.search,
        size: 20,
        color: colorScheme.onSurfaceVariant,
      ),
      suffixIcon: _buildClearButton(),
    );
  }

  OutlineInputBorder _buildOutlineInputBorder({
    Color? borderColor,
    double width = 1,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(24.0),
      borderSide: borderColor != null
          ? BorderSide(color: borderColor, width: width)
          : BorderSide.none,
    );
  }

  Widget? _buildClearButton() {
    if (_searchController.text.isEmpty) return null;

    return IconButton(
      icon: const Icon(Icons.clear, size: 20),
      onPressed: _clearSearch,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    setState(() {
      _selectedType = null;
    });
  }

  void _handleSearchTextChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    if (query.trim().isEmpty) {
      setState(() {});
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _triggerSearch(query);
      }
    });
  }

  void _handleSearchSubmitted(String value) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      _triggerSearch(trimmed);
    }
  }

  Widget _buildBody() {
    return BlocConsumer<SearchBloc, SearchState>(
      listener: _handleStateChanges,
      builder: _buildStateBasedContent,
    );
  }

  void _handleStateChanges(BuildContext context, SearchState state) {
    if (state is SuggestionError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    } else if (state is VideosError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.message)),
      );
    }
  }

  Widget _buildStateBasedContent(BuildContext context, SearchState state) {
    if (_searchController.text.trim().isEmpty) {
      return _buildRecentsState();
    }

    return switch (state) {
      SearchQueryLoading() => _buildLoadingShimmer(),
      VideosError(message: final message) => _buildErrorState(message),
      SearchResultsLoaded() => _buildSearchResults(state),
      _ => _buildLoadingShimmer(),
    };
  }

  Widget _buildLoadingShimmer() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterChips(),
          const SizedBox(height: 16),
          const _ShimmerList(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedType == filter['type'];
          
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                filter['label'],
                style: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedType = filter['type'];
                  });
                  _triggerSearch(_searchController.text);
                }
              },
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(128),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant.withAlpha(128),
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResults(SearchResultsLoaded state) {
    if (_selectedType == null) {
      return _buildAllResults(state);
    } else {
      return _buildCategoryResults(state);
    }
  }

  Widget _buildAllResults(SearchResultsLoaded state) {
    final results = state.results;
    if (results.isEmpty) return _buildEmptyState();

    final top = _pickTopResult(results);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFilterChips(),
          const SizedBox(height: 16),
          if (state.fromOfflineCache) ...[
            const _OfflineSearchBanner(),
            const SizedBox(height: 16),
          ],
          if (top != null) ...[
            _TopResultCard(top: top, onInteraction: _loadRecents),
            const SizedBox(height: 16),
          ],
          if (results.tracks.isNotEmpty) ...[
            _buildSectionHeader('Songs', 'track'),
            ...results.tracks.take(5).map(
                  (t) => _TrackTile(
                    track: t,
                    isCached: state.cachedTrackIds.contains(t.trackId),
                    onInteraction: _loadRecents,
                  ),
                ),
            const SizedBox(height: 16),
          ],
          if (results.artists.isNotEmpty) ...[
            _buildSectionHeader('Artists', 'artist'),
            ...results.artists.take(5).map(
                  (a) => _ArtistTile(
                    artist: a,
                    onInteraction: _loadRecents,
                  ),
                ),
            const SizedBox(height: 16),
          ],
          if (results.albums.isNotEmpty) ...[
            _buildSectionHeader('Albums', 'album'),
            ...results.albums.take(5).map(
                  (a) => _AlbumTile(
                    album: a,
                    isCached: state.cachedAlbumIds.contains(a.albumId),
                    onInteraction: _loadRecents,
                  ),
                ),
            const SizedBox(height: 16),
          ],
          if (results.playlists.isNotEmpty) ...[
            _buildSectionHeader('Playlists', 'playlist'),
            ...results.playlists.take(5).map(
                  (p) => _PlaylistTile(
                    playlist: p,
                    isCached: state.cachedPlaylistIds.contains(p.playlistId),
                    onInteraction: _loadRecents,
                  ),
                ),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryResults(SearchResultsLoaded state) {
    final results = state.results;
    
    final List<Widget> items = [];
    if (_selectedType == 'track') {
      items.addAll(results.tracks.map(
        (t) => _TrackTile(
          track: t,
          isCached: state.cachedTrackIds.contains(t.trackId),
          onInteraction: _loadRecents,
        ),
      ));
    } else if (_selectedType == 'artist') {
      items.addAll(results.artists.map(
        (a) => _ArtistTile(
          artist: a,
          onInteraction: _loadRecents,
        ),
      ));
    } else if (_selectedType == 'album') {
      items.addAll(results.albums.map(
        (a) => _AlbumTile(
          album: a,
          isCached: state.cachedAlbumIds.contains(a.albumId),
          onInteraction: _loadRecents,
        ),
      ));
    } else if (_selectedType == 'playlist') {
      items.addAll(results.playlists.map(
        (p) => _PlaylistTile(
          playlist: p,
          isCached: state.cachedPlaylistIds.contains(p.playlistId),
          onInteraction: _loadRecents,
        ),
      ));
    }

    if (items.isEmpty) return _buildEmptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length + 2, // 1 for filter chips, 1 for bottom loader
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterChips(),
              const SizedBox(height: 16),
              if (state.fromOfflineCache) ...[
                const _OfflineSearchBanner(),
                const SizedBox(height: 16),
              ],
            ],
          );
        }
        
        final itemIndex = index - 1;
        if (itemIndex < items.length) {
          return items[itemIndex];
        }
        
        // Bottom loader
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: state.isFetchingMore
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, String type) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedType = type;
              });
              _triggerSearch(_searchController.text);
            },
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              padding: EdgeInsets.zero,
              minimumSize: const Size(50, 30),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('See all'),
          ),
        ],
      ),
    );
  }

  Object? _pickTopResult(CatalogSearchResults r) {
    if (r.artists.isNotEmpty) return r.artists.first;
    if (r.tracks.isNotEmpty) return r.tracks.first;
    if (r.albums.isNotEmpty) return r.albums.first;
    if (r.playlists.isNotEmpty) return r.playlists.first;
    return null;
  }

  Widget _buildRecentsState() {
    if (_isLoadingRecents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_recents.isEmpty) {
      return _buildEmptyState();
    }

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent searches',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _clearRecents,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.primary,
                ),
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _recents.length,
              itemBuilder: (context, index) {
                final item = _recents[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _openRecent(item),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withAlpha(50),
                        ),
                      ),
                      child: Row(
                        children: [
                          _buildRecentLeading(item),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    _buildTypeBadge(item.type),
                                    if (item.subtitle != null) ...[
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          item.subtitle!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: theme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentLeading(SearchRecentItem item) {
    final isArtist = item.type == SearchRecentType.artist;
    final borderRadius = isArtist ? 24.0 : 8.0;

    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.network(
          item.imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallbackIcon(item.type, borderRadius),
        ),
      );
    }

    return _buildFallbackIcon(item.type, borderRadius);
  }

  Widget _buildFallbackIcon(SearchRecentType type, double borderRadius) {
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        _iconForType(type),
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTypeBadge(SearchRecentType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(100),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        switch (type) {
          SearchRecentType.track => 'Song',
          SearchRecentType.album => 'Album',
          SearchRecentType.artist => 'Artist',
          SearchRecentType.playlist => 'Playlist',
        },
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: 10,
        ),
      ),
    );
  }

  IconData _iconForType(SearchRecentType type) {
    return switch (type) {
      SearchRecentType.track => Icons.music_note,
      SearchRecentType.album => Icons.album,
      SearchRecentType.artist => Icons.person,
      SearchRecentType.playlist => Icons.queue_music_rounded,
    };
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: colorScheme.primary.withAlpha(153),
            ),
            const SizedBox(height: 16),
            Text(
              'Search the catalog',
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a search term above to find songs, albums, artists, and playlists',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withAlpha(179),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _retrySearch,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _retrySearch() {
    if (_searchController.text.isNotEmpty) {
      _triggerSearch(_searchController.text);
    }
  }

  Future<void> _loadRecents() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecents = true;
    });

    final recents = await _recentsService.getRecents(limit: 12);
    if (!mounted) return;

    setState(() {
      _recents = recents;
      _isLoadingRecents = false;
    });
  }

  Future<void> _clearRecents() async {
    await _recentsService.clearRecents();
    await _loadRecents();
  }

  Future<void> _openRecent(SearchRecentItem item) async {
    await _recentsService.addRecent(item);
    if (!mounted) return;

    switch (item.type) {
      case SearchRecentType.track:
        await showPlayerBottomSheet(
          context,
          trackId: item.id,
          audioUrl: null,
          title: item.title,
          artist: item.subtitle ?? 'Unknown Artist',
          imageUrl: item.imageUrl,
        );
        break;
      case SearchRecentType.album:
        await context.push('/albums/${item.id}');
        break;
      case SearchRecentType.artist:
        await context.push('/artists/${item.id}');
        break;
      case SearchRecentType.playlist:
        await context.push('/playlists/${item.id}');
        break;
    }

    await _loadRecents();
  }
}

class _TopResultCard extends StatelessWidget {
  final Object top; // CatalogArtist | CatalogTrack | CatalogAlbum | CatalogPlaylist
  final VoidCallback? onInteraction;

  const _TopResultCard({required this.top, this.onInteraction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _artwork(context),
              const SizedBox(width: 16),
              Expanded(child: _info(context)),
            ],
          ),
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
    } else if (top is CatalogTrack) {
      imageUrl = (top as CatalogTrack).imageUrl;
      fallback = Icons.music_note_rounded;
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

  Future<void> _handleTap(BuildContext context) async {
    if (top is CatalogArtist) {
      final a = top as CatalogArtist;
      await GetIt.I<SearchRecentsService>().addRecent(
        SearchRecentItem(
          type: SearchRecentType.artist,
          id: a.artistId,
          title: a.name ?? 'Artist',
          subtitle: 'Artist',
          imageUrl: a.avatarUrl,
          updatedAt: DateTime.now(),
        ),
      );
      if (onInteraction != null) onInteraction!();
      if (!context.mounted) return;
      await context.push('/artists/${a.artistId}');
      if (onInteraction != null) onInteraction!();
    } else if (top is CatalogTrack) {
      final t = top as CatalogTrack;
      final artistNames = t.artists.map((a) => a.name ?? a.artistId).join(', ');
      await GetIt.I<SearchRecentsService>().addRecent(
        SearchRecentItem(
          type: SearchRecentType.track,
          id: t.trackId,
          title: t.title,
          subtitle: artistNames,
          imageUrl: t.imageUrl,
          updatedAt: DateTime.now(),
        ),
      );
      if (onInteraction != null) onInteraction!();
      if (!context.mounted) return;
      await showPlayerBottomSheet(
        context,
        trackId: t.trackId,
        audioUrl: null,
        title: t.title,
        artist: artistNames,
        imageUrl: t.imageUrl,
      );
    } else if (top is CatalogPlaylist) {
      final p = top as CatalogPlaylist;
      final subtitle = p.creatorName?.isNotEmpty == true
          ? p.creatorName!
          : 'Playlist';
      await GetIt.I<SearchRecentsService>().addRecent(
        SearchRecentItem(
          type: SearchRecentType.playlist,
          id: p.playlistId,
          title: p.name,
          subtitle: subtitle,
          imageUrl: p.coverUrl,
          updatedAt: DateTime.now(),
        ),
      );
      if (onInteraction != null) onInteraction!();
      if (!context.mounted) return;
      await context.push('/playlists/${p.playlistId}');
      if (onInteraction != null) onInteraction!();
    } else if (top is CatalogAlbum) {
      final a = top as CatalogAlbum;
      final artistNames = a.artists.map((x) => x.name ?? x.artistId).join(', ');
      await GetIt.I<SearchRecentsService>().addRecent(
        SearchRecentItem(
          type: SearchRecentType.album,
          id: a.albumId,
          title: a.title,
          subtitle: artistNames,
          imageUrl: a.coverUrl,
          updatedAt: DateTime.now(),
        ),
      );
      if (onInteraction != null) onInteraction!();
      if (!context.mounted) return;
      await context.push('/albums/${a.albumId}');
      if (onInteraction != null) onInteraction!();
    }
  }
}

class _TrackTile extends StatelessWidget {
  final CatalogTrack track;
  final bool isCached;
  final VoidCallback? onInteraction;

  const _TrackTile({required this.track, required this.isCached, this.onInteraction});

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
    if (onInteraction != null) onInteraction!();

    if (!context.mounted) return;
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
  final VoidCallback? onInteraction;

  const _ArtistTile({required this.artist, this.onInteraction});

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
          if (onInteraction != null) onInteraction!();
          if (!context.mounted) return;
          await context.push('/artists/${artist.artistId}');
          if (onInteraction != null) onInteraction!();
        },
      ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final CatalogAlbum album;
  final bool isCached;
  final VoidCallback? onInteraction;

  const _AlbumTile({required this.album, required this.isCached, this.onInteraction});

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
          if (onInteraction != null) onInteraction!();
          if (!context.mounted) return;
          await context.push('/albums/${album.albumId}');
          if (onInteraction != null) onInteraction!();
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
      if (onInteraction != null) onInteraction!();
      context.push('/albums/${album.albumId}');
      if (onInteraction != null) onInteraction!();
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
  final VoidCallback? onInteraction;

  const _PlaylistTile({required this.playlist, required this.isCached, this.onInteraction});

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
          if (onInteraction != null) onInteraction!();
          if (!context.mounted) return;
          await context.push('/playlists/${playlist.playlistId}');
          if (onInteraction != null) onInteraction!();
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
          Text(
            'Showing offline cached results',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
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

class _PulsePlaceholder extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _PulsePlaceholder({
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<_PulsePlaceholder> createState() => _PulsePlaceholderState();
}

class _PulsePlaceholderState extends State<_PulsePlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.15, end: 0.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface,
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class _ShimmerTile extends StatelessWidget {
  const _ShimmerTile();

  @override
  Widget build(BuildContext context) {
    return _ResultTileContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            const _PulsePlaceholder(width: 56, height: 56, borderRadius: 8),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _PulsePlaceholder(width: 160, height: 16),
                  const SizedBox(height: 8),
                  const _PulsePlaceholder(width: 100, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) => const _ShimmerTile(),
    );
  }
}
