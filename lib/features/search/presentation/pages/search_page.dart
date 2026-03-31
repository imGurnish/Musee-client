import 'package:musee/features/search/presentation/bloc/search_bloc.dart';
import 'package:musee/features/search/presentation/pages/search_suggestions_page.dart';
import 'package:musee/init_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Main search page that displays a search input field
/// Navigates to SearchSuggestionsPage when user taps the search field
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  // Controller for search input field (unused but kept for future functionality)
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  /// Builds the app bar with search input field
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: _buildSearchField(),
    );
  }

  /// Builds the search input field container
  Widget _buildSearchField() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextField(
        controller: _searchController,
        maxLines: 1,
        readOnly: true, // Makes field non-editable, only tappable
        style: const TextStyle(fontSize: 16),
        decoration: _buildSearchInputDecoration(),
        onTap: _navigateToSearchSuggestions,
      ),
    );
  }

  /// Builds the main body content
  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.primaryContainer.withAlpha(77),
                ),
                child: Icon(Icons.search, size: 64, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Search for music',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Tap the search bar above to find songs, albums, and artists',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withAlpha(179),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildSearchTipsSection(colorScheme, textTheme),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds search tips section with helpful suggestions
  Widget _buildSearchTipsSection(ColorScheme colorScheme, TextTheme textTheme) {
    final tips = [
      {'icon': Icons.trending_up, 'text': 'Try trending tracks'},
      {'icon': Icons.album, 'text': 'Search by album'},
      {'icon': Icons.person, 'text': 'Find your favorite artists'},
    ];

    return Column(
      children: [
        Text(
          'Search Tips',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface.withAlpha(230),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: tips
              .map(
                (tip) => _buildTipChip(
                  icon: tip['icon'] as IconData,
                  text: tip['text'] as String,
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  /// Builds individual tip chip
  Widget _buildTipChip({
    required IconData icon,
    required String text,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(128),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outline.withAlpha(77), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withAlpha(204),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Creates input decoration for the search field
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

  /// Navigates to search suggestions page with proper BLoC provider
  void _navigateToSearchSuggestions() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => BlocProvider(
          create: (context) => SearchBloc(serviceLocator(), serviceLocator()),
          child: const SearchSuggestionsPage(),
        ),
      ),
    );
  }
}
