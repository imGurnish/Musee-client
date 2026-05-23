import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/common/widgets/playing_bars_animation.dart';
import 'package:musee/init_dependencies.dart';

import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/features/user_playlists/presentation/widgets/add_to_playlist_sheet.dart';

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
          !state.isFetchingMore) {
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
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedType == filter['type'];
          
          return Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: _CustomFilterChip(
              label: filter['label'],
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedType = filter['type'];
                });
                _triggerSearch(_searchController.text);
              },
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
    if (results.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterChips(),
            const SizedBox(height: 24),
            _buildNoResultsState(_searchController.text),
          ],
        ),
      );
    }

    final top = _pickTopResult(results);
    final mixedItems = _buildUnifiedMixedList(results, top);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 1 + // Filter chips
          (state.fromOfflineCache ? 1 : 0) + // Offline banner
          (top != null ? 1 : 0) + // Top result card
          mixedItems.length + // Unified mixed items
          1, // Bottom loader / spacing
      itemBuilder: (context, index) {
        int currentIndex = 0;

        // 1. Filter Chips
        if (index == currentIndex) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterChips(),
              const SizedBox(height: 16),
            ],
          );
        }
        currentIndex++;

        // 2. Offline Banner
        if (state.fromOfflineCache) {
          if (index == currentIndex) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16.0),
              child: _OfflineSearchBanner(),
            );
          }
          currentIndex++;
        }

        // 3. Top Result Card
        if (top != null) {
          if (index == currentIndex) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: _TopResultCard(top: top, onInteraction: _loadRecents),
            );
          }
          currentIndex++;
        }

        // 4. Unified Mixed Items
        final mixedItemIndex = index - currentIndex;
        if (mixedItemIndex >= 0 && mixedItemIndex < mixedItems.length) {
          final item = mixedItems[mixedItemIndex];
          return _buildMixedItemTile(item, state);
        }

        // 5. Bottom Loader / Spacing
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: state.isFetchingMore
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Widget _buildCategoryResults(SearchResultsLoaded state) {
    final results = state.results;
    
    final List<Widget> items = [];
    int totalCount = 0;
    String categoryLabel = '';
    
    if (_selectedType == 'track') {
      totalCount = results.tracks.length;
      categoryLabel = 'Songs';
      items.addAll(results.tracks.map(
        (t) => _TrackTile(
          track: t,
          isCached: state.cachedTrackIds.contains(t.trackId),
          onInteraction: _loadRecents,
        ),
      ));
    } else if (_selectedType == 'artist') {
      totalCount = results.artists.length;
      categoryLabel = 'Artists';
      items.addAll(results.artists.map(
        (a) => _ArtistTile(
          artist: a,
          onInteraction: _loadRecents,
        ),
      ));
    } else if (_selectedType == 'album') {
      totalCount = results.albums.length;
      categoryLabel = 'Albums';
      items.addAll(results.albums.map(
        (a) => _AlbumTile(
          album: a,
          isCached: state.cachedAlbumIds.contains(a.albumId),
          onInteraction: _loadRecents,
        ),
      ));
    } else if (_selectedType == 'playlist') {
      totalCount = results.playlists.length;
      categoryLabel = 'Playlists';
      items.addAll(results.playlists.map(
        (p) => _PlaylistTile(
          playlist: p,
          isCached: state.cachedPlaylistIds.contains(p.playlistId),
          onInteraction: _loadRecents,
        ),
      ));
    }

    if (items.isEmpty) {
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
            _CategoryHeaderCard(
              label: categoryLabel,
              totalCount: 0,
              query: _searchController.text,
            ),
            const SizedBox(height: 24),
            _buildNoResultsState(_searchController.text),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 1 + // Filter chips + Category header card + Offline banner (combined in index 0)
          items.length + // Result items
          1, // Bottom loader / spacing
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
              _CategoryHeaderCard(
                label: categoryLabel,
                totalCount: totalCount,
                query: _searchController.text,
              ),
            ],
          );
        }
        
        final itemIndex = index - 1;
        if (itemIndex < items.length) {
          return items[itemIndex];
        }
        
        // Bottom loader
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: state.isFetchingMore
              ? const Center(child: CircularProgressIndicator())
              : const SizedBox.shrink(),
        );
      },
    );
  }

  Object? _pickTopResult(CatalogSearchResults r) {
    if (r.artists.isNotEmpty) return r.artists.first;
    if (r.tracks.isNotEmpty) return r.tracks.first;
    if (r.albums.isNotEmpty) return r.albums.first;
    if (r.playlists.isNotEmpty) return r.playlists.first;
    return null;
  }

  double _computeRelevance(Object item, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return 0.0;

    String primaryText = '';
    String secondaryText = '';
    double typeWeight = 0.0;

    if (item is CatalogTrack) {
      primaryText = item.title;
      secondaryText = item.artists.map((a) => a.name ?? '').join(' ');
      typeWeight = 4.0;
    } else if (item is CatalogArtist) {
      primaryText = item.name ?? '';
      typeWeight = 3.0;
    } else if (item is CatalogAlbum) {
      primaryText = item.title;
      secondaryText = item.artists.map((a) => a.name ?? '').join(' ');
      typeWeight = 2.0;
    } else if (item is CatalogPlaylist) {
      primaryText = item.name;
      secondaryText = item.creatorName ?? '';
      typeWeight = 1.0;
    }

    primaryText = primaryText.trim().toLowerCase();
    secondaryText = secondaryText.trim().toLowerCase();

    double score = 0.0;

    // Primary text matching
    if (primaryText == q) {
      score += 100.0;
    } else if (primaryText.startsWith(q)) {
      score += 50.0;
    } else if (primaryText.contains(' $q') || primaryText.contains('$q ')) {
      score += 30.0;
    } else if (primaryText.contains(q)) {
      score += 10.0;
    }

    // Secondary text matching
    if (secondaryText.isNotEmpty) {
      if (secondaryText == q) {
        score += 40.0;
      } else if (secondaryText.startsWith(q)) {
        score += 20.0;
      } else if (secondaryText.contains(q)) {
        score += 5.0;
      }
    }

    return score + (score > 0 ? typeWeight : 0.0);
  }

  List<Object> _buildUnifiedMixedList(CatalogSearchResults results, Object? topResult) {
    final List<Object> mixed = [];
    
    bool isTopResult(Object item) {
      if (topResult == null) return false;
      if (item is CatalogTrack && topResult is CatalogTrack) {
        return item.trackId == topResult.trackId;
      }
      if (item is CatalogArtist && topResult is CatalogArtist) {
        return item.artistId == topResult.artistId;
      }
      if (item is CatalogAlbum && topResult is CatalogAlbum) {
        return item.albumId == topResult.albumId;
      }
      if (item is CatalogPlaylist && topResult is CatalogPlaylist) {
        return item.playlistId == topResult.playlistId;
      }
      return false;
    }

    for (final t in results.tracks) {
      if (!isTopResult(t)) mixed.add(t);
    }
    for (final a in results.artists) {
      if (!isTopResult(a)) mixed.add(a);
    }
    for (final al in results.albums) {
      if (!isTopResult(al)) mixed.add(al);
    }
    for (final p in results.playlists) {
      if (!isTopResult(p)) mixed.add(p);
    }

    final query = _searchController.text;
    mixed.sort((a, b) {
      final scoreA = _computeRelevance(a, query);
      final scoreB = _computeRelevance(b, query);
      return scoreB.compareTo(scoreA);
    });

    return mixed;
  }

  Widget _buildMixedItemTile(Object item, SearchResultsLoaded state) {
    if (item is CatalogTrack) {
      return _TrackTile(
        track: item,
        isCached: state.cachedTrackIds.contains(item.trackId),
        onInteraction: _loadRecents,
      );
    } else if (item is CatalogArtist) {
      return _ArtistTile(
        artist: item,
        onInteraction: _loadRecents,
      );
    } else if (item is CatalogAlbum) {
      return _AlbumTile(
        album: item,
        isCached: state.cachedAlbumIds.contains(item.albumId),
        onInteraction: _loadRecents,
      );
    } else if (item is CatalogPlaylist) {
      return _PlaylistTile(
        playlist: item,
        isCached: state.cachedPlaylistIds.contains(item.playlistId),
        onInteraction: _loadRecents,
      );
    }
    return const SizedBox.shrink();
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
                          GestureDetector(
                            onTap: () {
                              _removeRecentItem(item);
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: theme.colorScheme.onSurfaceVariant,
                                size: 16,
                              ),
                            ),
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

  Widget _buildNoResultsState(String query) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sentiment_dissatisfied_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                children: [
                  const TextSpan(text: 'We couldn\'t find any matches for '),
                  TextSpan(
                    text: '"$query"',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const TextSpan(text: '.\nPlease check spelling or try other keywords.'),
                ],
              ),
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

  Future<void> _removeRecentItem(SearchRecentItem item) async {
    await _recentsService.removeRecent(item.uniqueKey);
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
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withAlpha(160),
            colorScheme.surfaceContainerHighest.withAlpha(60),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.primary.withAlpha(40),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                _artwork(context),
                const SizedBox(width: 20),
                Expanded(child: _info(context)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _artwork(BuildContext context) {
    final double size = 88;
    String? imageUrl;
    IconData fallback = Icons.music_note;
    bool isCircle = false;
    if (top is CatalogAlbum) {
      imageUrl = (top as CatalogAlbum).coverUrl;
      fallback = Icons.album;
    } else if (top is CatalogArtist) {
      imageUrl = (top as CatalogArtist).avatarUrl;
      fallback = Icons.person;
      isCircle = true;
    } else if (top is CatalogPlaylist) {
      imageUrl = (top as CatalogPlaylist).coverUrl;
      fallback = Icons.queue_music_rounded;
    } else if (top is CatalogTrack) {
      imageUrl = (top as CatalogTrack).imageUrl;
      fallback = Icons.music_note_rounded;
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(60),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: isCircle ? BorderRadius.circular(size / 2) : BorderRadius.circular(16),
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(imageUrl, fit: BoxFit.cover)
              : Icon(fallback, size: 40),
        ),
      ),
    );
  }

  Widget _info(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    String title;
    String subtitle;
    String typeLabel;
    
    if (top is CatalogArtist) {
      final a = top as CatalogArtist;
      title = a.name ?? 'Artist';
      subtitle = 'Popular Artist';
      typeLabel = 'Artist';
    } else if (top is CatalogTrack) {
      final t = top as CatalogTrack;
      title = t.title;
      final artistNames = t.artists.map((a) => a.name ?? a.artistId).join(', ');
      subtitle = 'Song • $artistNames';
      typeLabel = 'Song';
    } else if (top is CatalogPlaylist) {
      final p = top as CatalogPlaylist;
      title = p.name;
      subtitle = p.creatorName?.isNotEmpty == true
          ? 'Playlist • By ${p.creatorName}'
          : 'Playlist';
      typeLabel = 'Playlist';
    } else {
      final a = top as CatalogAlbum;
      title = a.title;
      final artistNames = a.artists.map((x) => x.name ?? x.artistId).join(', ');
      subtitle = 'Album • $artistNames';
      typeLabel = 'Album';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TypeBadge(label: typeLabel),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            letterSpacing: 0.1,
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

class _TypeBadge extends StatelessWidget {
  final String label;
  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withAlpha(40),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.primary.withAlpha(80),
          width: 0.8,
        ),
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 1.2,
        ),
      ),
    );
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
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Add to playlist'),
              onTap: () => Navigator.pop(context, 'playlist'),
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

    if (action == 'playlist') {
      await showAddToPlaylistSheet(
        context,
        trackId: track.trackId,
        trackTitle: track.title,
        artistNames: artistNames,
        imageUrl: track.imageUrl,
      );
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
    final theme = Theme.of(context);

    return _ResultTileContainer(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      artist.avatarUrl != null && artist.avatarUrl!.isNotEmpty
                          ? Image.network(
                              artist.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                                child: const Icon(Icons.person, size: 28),
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.person, size: 28),
                            ),
                      BlocBuilder<PlayerCubit, PlayerViewState>(
                        builder: (context, state) {
                          final isActive = state.track?.artistId == artist.artistId;
                          if (!isActive) return const SizedBox.shrink();

                          return BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: Container(
                              color: theme.colorScheme.surface.withValues(alpha: 0.35),
                              alignment: Alignment.center,
                              child: PlayingBarsAnimation(
                                width: 22,
                                height: 18,
                                isPlaying: state.playing,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      artist.name ?? 'Artist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Artist',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const _TypeChip(label: 'Artist'),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    final subtitle = playlist.creatorName?.isNotEmpty == true
        ? 'Playlist • By ${playlist.creatorName}'
        : 'Playlist';

    return _ResultTileContainer(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await GetIt.I<SearchRecentsService>().addRecent(
            SearchRecentItem(
              type: SearchRecentType.playlist,
              id: playlist.playlistId,
              title: playlist.name,
              subtitle: playlist.creatorName?.isNotEmpty == true
                  ? playlist.creatorName!
                  : 'Playlist',
              imageUrl: playlist.coverUrl,
              updatedAt: DateTime.now(),
            ),
          );
          if (onInteraction != null) onInteraction!();
          if (!context.mounted) return;
          await context.push('/playlists/${playlist.playlistId}');
          if (onInteraction != null) onInteraction!();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
          child: Row(
            children: [
              _PlaylistArtwork(playlist: playlist, isCached: isCached),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const _TypeChip(label: 'Playlist'),
            ],
          ),
        ),
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
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.12),
            width: 1.0,
          ),
        ),
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
          BlocBuilder<PlayerCubit, PlayerViewState>(
            builder: (context, state) {
              final isActive = state.track?.trackId == track.trackId;
              if (!isActive) return const SizedBox.shrink();

              return Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: theme.colorScheme.surface.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: PlayingBarsAnimation(
                        width: 22,
                        height: 18,
                        isPlaying: state.playing,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
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
          BlocBuilder<PlayerCubit, PlayerViewState>(
            builder: (context, state) {
              final isActive = state.track?.albumId == album.albumId;
              if (!isActive) return const SizedBox.shrink();

              return Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: theme.colorScheme.surface.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: PlayingBarsAnimation(
                        width: 22,
                        height: 18,
                        isPlaying: state.playing,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
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
          BlocBuilder<PlayerCubit, PlayerViewState>(
            builder: (context, state) {
              final isActive = state.track?.playlistId == playlist.playlistId;
              if (!isActive) return const SizedBox.shrink();

              return Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      color: theme.colorScheme.surface.withValues(alpha: 0.35),
                      alignment: Alignment.center,
                      child: PlayingBarsAnimation(
                        width: 22,
                        height: 18,
                        isPlaying: state.playing,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              );
            },
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.38),
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

class _CustomFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CustomFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  colorScheme.primary,
                  colorScheme.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected
            ? null
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.2)
              : colorScheme.outlineVariant.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeaderCard extends StatelessWidget {
  final String label;
  final int totalCount;
  final String query;

  const _CategoryHeaderCard({
    required this.label,
    required this.totalCount,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
              children: [
                const TextSpan(text: 'Showing '),
                TextSpan(
                  text: '$totalCount',
                  style: TextStyle(color: colorScheme.primary),
                ),
                const TextSpan(text: ' results for '),
                TextSpan(
                  text: '"$query"',
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
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
