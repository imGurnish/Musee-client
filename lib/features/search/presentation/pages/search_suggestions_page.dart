import 'package:musee/features/search/presentation/bloc/search_bloc.dart';
import 'package:musee/features/search/data/services/search_recents_service.dart';
import 'package:musee/features/search/domain/entities/search_recent_item.dart';
import 'package:musee/features/search/presentation/pages/search_results_page.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/init_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Search suggestions page that displays search suggestions as user types
/// Provides autocomplete functionality and navigation to search results
class SearchSuggestionsPage extends StatefulWidget {
  final String? query;

  const SearchSuggestionsPage({super.key, this.query});

  @override
  State<SearchSuggestionsPage> createState() => _SearchSuggestionsPageState();
}

class _SearchSuggestionsPageState extends State<SearchSuggestionsPage> {
  late final TextEditingController _searchController;
  late final SearchRecentsService _recentsService;
  List<SearchRecentItem> _recents = const <SearchRecentItem>[];
  bool _isLoadingRecents = false;

  @override
  void initState() {
    super.initState();
    _recentsService = serviceLocator<SearchRecentsService>();
    _searchController = TextEditingController(text: widget.query);
    _setupSearchControllerListener();
    _initializeWithQuery();
    _loadRecents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Sets up listener for search controller to update UI
  void _setupSearchControllerListener() {
    _searchController.addListener(() {
      setState(() {}); // Update UI for clear button visibility
    });
  }

  /// Initializes page with existing query if provided
  void _initializeWithQuery() {
    if (widget.query?.isNotEmpty == true) {
      _triggerSuggestions(widget.query!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
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
      // actions: const [SizedBox(width: 8)],
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

  /// Creates consistent outline input border
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

  /// Builds clear button when text is present
  Widget? _buildClearButton() {
    if (_searchController.text.isEmpty) return null;

    return IconButton(
      icon: const Icon(Icons.clear, size: 20),
      onPressed: _clearSearch,
    );
  }

  /// Builds main body with BLoC consumer
  Widget _buildBody() {
    return BlocConsumer<SearchBloc, SearchState>(
      listener: _handleStateChanges,
      builder: _buildStateBasedContent,
    );
  }

  /// Handles state changes and shows error messages
  void _handleStateChanges(BuildContext context, SearchState state) {
    if (state is SuggestionError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  /// Builds content based on current BLoC state
  Widget _buildStateBasedContent(BuildContext context, SearchState state) {
    if (_searchController.text.trim().isEmpty) {
      return _buildRecentsState();
    }

    return switch (state) {
      SuggestionLoading() => _buildLoadingState(),
      SuggestionError(message: final message) => _buildErrorState(message),
      SuggestionLoaded(suggestions: final suggestions) =>
        suggestions.isEmpty
            ? _buildEmptyState()
            : _buildSuggestionsList(suggestions),
      _ => _buildInitialState(),
    };
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
                        color: theme.colorScheme.surfaceContainerHighest
                            .withAlpha(50),
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
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
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
          errorBuilder: (_, _, _) =>
              _buildFallbackIcon(item.type, borderRadius),
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

  /// Builds loading state with centered indicator
  Widget _buildLoadingState() {
    return const Center(child: CircularProgressIndicator());
  }

  /// Builds initial/empty state with search guidance
  Widget _buildInitialState() {
    return _buildEmptyState();
  }

  /// Builds empty state with helpful message
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

  /// Builds suggestions list with proper styling
  Widget _buildSuggestionsList(List<dynamic> suggestions) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: _buildSuggestionsContainerDecoration(),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: suggestions.length,
        separatorBuilder: _buildSuggestionSeparator,
        itemBuilder: (context, index) =>
            _buildSuggestionItem(suggestions[index]),
      ),
    );
  }

  /// Creates decoration for suggestions container
  BoxDecoration _buildSuggestionsContainerDecoration() {
    return BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(26),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  /// Builds separator between suggestions
  Widget _buildSuggestionSeparator(BuildContext context, int index) {
    return Divider(
      height: 1,
      color: Theme.of(context).dividerColor.withAlpha(77),
    );
  }

  /// Builds individual suggestion list item
  Widget _buildSuggestionItem(dynamic suggestion) {
    return ListTile(
      leading: const Icon(Icons.search, size: 20),
      title: Text(
        suggestion.text,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: _buildSuggestionFillButton(suggestion.text),
      onTap: () => _handleSuggestionSelected(suggestion.text),
    );
  }

  /// Builds button to fill search field with suggestion
  Widget _buildSuggestionFillButton(String suggestionText) {
    return IconButton(
      icon: const Icon(Icons.north_west, size: 16),
      tooltip: 'Fill search field',
      onPressed: () => _fillSearchField(suggestionText),
    );
  }

  /// Builds error state with retry functionality
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

  /// Handles search text changes and triggers suggestions
  void _handleSearchTextChanged(String query) {
    if (query.trim().isNotEmpty) {
      _triggerSuggestions(query);
      return;
    }

    setState(() {});
  }

  /// Handles search submission and navigates to results
  void _handleSearchSubmitted(String value) {
    if (value.trim().isNotEmpty) {
      _navigateToSearchResults(value.trim());
    }
  }

  /// Handles suggestion selection and navigates to results
  void _handleSuggestionSelected(String suggestion) {
    _navigateToSearchResults(suggestion);
  }

  /// Fills search field with suggestion text
  void _fillSearchField(String suggestionText) {
    _searchController.text = suggestionText;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestionText.length),
    );
  }

  /// Clears search field and resets state
  void _clearSearch() {
    _searchController.clear();
  }

  /// Triggers suggestion fetch from BLoC
  void _triggerSuggestions(String query) {
    context.read<SearchBloc>().add(FetchSuggestions(query: query));
  }

  /// Retries search with current text
  void _retrySearch() {
    if (_searchController.text.isNotEmpty) {
      _triggerSuggestions(_searchController.text);
    }
  }

  /// Navigates to search results.
  ///
  /// When opened from a results page (canPop == true), we pop and return the
  /// query — the results page receives it and pushes a new results page on top.
  /// When we are the root of the search tab (canPop == false), we push results
  /// directly on top of ourselves and reload recents when we return.
  Future<void> _navigateToSearchResults(String query) async {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop(query);
    } else {
      await nav.push(
        MaterialPageRoute<void>(
          builder: (_) => BlocProvider(
            create: (_) => SearchBloc(serviceLocator(), serviceLocator()),
            child: SearchResultsPage(query: query),
          ),
        ),
      );
      // Reload recents when returning from results — the user may have
      // tapped tracks/albums/artists which added new recent entries.
      _loadRecents();
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
