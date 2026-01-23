import 'package:musee/features/search/presentation/bloc/search_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.query);
    _setupSearchControllerListener();
    _initializeWithQuery();
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
      titleSpacing: 0,
      actions: [IconButton(icon: const Icon(Icons.mic), onPressed: () => {})],
      actionsPadding: const EdgeInsets.symmetric(horizontal: 4),
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
        style: const TextStyle(fontSize: 16),
        decoration: _buildSearchInputDecoration(),
        onChanged: _handleSearchTextChanged,
        onSubmitted: _handleSearchSubmitted,
      ),
    );
  }

  /// Creates search field decoration with clear button
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
      hintText: 'Search songs, albums, artists',
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
      suffixIcon: _buildClearButton(),
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
              'Enter a search term above to find songs, albums, and artists',
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
    if (query.isNotEmpty) {
      _triggerSuggestions(query);
    }
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

  /// Navigates to search results page
  void _navigateToSearchResults(String query) {
    context.pop();
    context.push("/search?q=${Uri.encodeComponent(query)}");
  }
}
