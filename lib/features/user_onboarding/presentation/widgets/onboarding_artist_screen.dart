import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';

class OnboardingArtistScreen extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingArtistScreen({
    super.key,
    required this.onNext,
  });

  @override
  State<OnboardingArtistScreen> createState() => _OnboardingArtistScreenState();
}

class _OnboardingArtistScreenState extends State<OnboardingArtistScreen> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<OnboardingBloc>().add(const SearchArtistsEvent(''));
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 20 : 40,
          vertical: isMobile ? 30 : 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Favorite Artists',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Search and select your favorite artists (optional)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            // Search field
            _buildSearchField(),
            const SizedBox(height: 24),
            // Selected artists (chips)
            BlocBuilder<OnboardingBloc, OnboardingState>(
              builder: (context, state) {
                if (state.selectedArtists.isEmpty) {
                  return SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selected Artists',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: state.selectedArtists.map((artist) {
                        return _buildSelectedArtistChip(
                          context,
                          artist.name,
                          () {
                            context.read<OnboardingBloc>().add(
                              RemoveSelectedArtistEvent(artist.id),
                            );
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
            // Search results
            BlocBuilder<OnboardingBloc, OnboardingState>(
              builder: (context, state) {
                if (state.isSearching) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                if (state.searchResults.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'No artists found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.searchResults.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final artist = state.searchResults[index];
                    final isSelected = state.selectedArtists.any((a) => a.id == artist.id);

                    return _buildArtistSearchResult(
                      context,
                      artist.name,
                      artist.imageUrl,
                      artist.genre,
                      isSelected,
                      () {
                        context.read<OnboardingBloc>().add(
                          SelectArtistEvent(artist),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      keyboardType: TextInputType.text,
      onChanged: (value) {
        context.read<OnboardingBloc>().add(SearchArtistsEvent(value));
      },
      decoration: InputDecoration(
        hintText: 'Search artists...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            _searchController.clear();
            context.read<OnboardingBloc>().add(const SearchArtistsEvent(''));
          },
        )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildSelectedArtistChip(
    BuildContext context,
    String name,
    VoidCallback onRemove,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistSearchResult(
    BuildContext context,
    String name,
    String? imageUrl,
    String? genre,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Artist image or placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[300],
                image: imageUrl != null
                    ? DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: imageUrl == null
                  ? const Icon(Icons.person, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 12),
            // Artist info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  if (genre != null)
                    Text(
                      genre,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            // Checkmark if selected
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
