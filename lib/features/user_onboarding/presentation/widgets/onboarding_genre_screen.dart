import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';

class OnboardingGenreScreen extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingGenreScreen({
    super.key,
    required this.onNext,
  });

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
              'Your Favorite Genres',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Select genres you enjoy (choose at least 1)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 30),
            // Genre grid
            BlocBuilder<OnboardingBloc, OnboardingState>(
              builder: (context, state) {
                if (state.isLoading) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: state.genres.map((genre) {
                    final isSelected = genre.isSelected;

                    return _buildGenreChip(
                      context,
                      genre.name,
                      genre.icon,
                      isSelected,
                      () {
                        context.read<OnboardingBloc>().add(
                          SelectGenreEvent(genre.id),
                        );
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 30),
            // Selection counter
            BlocBuilder<OnboardingBloc, OnboardingState>(
              builder: (context, state) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '✓',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.selectedGenres.isEmpty
                              ? 'Select at least 1 genre'
                              : '${state.selectedGenres.length} genre${state.selectedGenres.length > 1 ? 's' : ''} selected',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreChip(
    BuildContext context,
    String name,
    String icon,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              icon,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 8),
            Text(
              name,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
