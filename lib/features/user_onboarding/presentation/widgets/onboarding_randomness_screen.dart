import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';

class OnboardingRandomnessScreen extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingRandomnessScreen({
    super.key,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return isDesktop ? _buildDesktopRandomness(context) : _buildMobileRandomness(context);
  }

  Widget _buildMobileRandomness(BuildContext context) {
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
              'Discovery Preferences',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'How adventurous do you want your music experience?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 40),
            // Randomness slider
            BlocBuilder<OnboardingBloc, OnboardingState>(
              builder: (context, state) {
                return Column(
                  children: [
                    // Slider
                    Slider(
                      value: state.randomnessPercentage.toDouble(),
                      min: 0,
                      max: 50,
                      divisions: 50,
                      onChanged: (value) {
                        context.read<OnboardingBloc>().add(
                          UpdateRandomnessEvent(value.toInt()),
                        );
                      },
                      activeColor: Theme.of(context).colorScheme.primary,
                      inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 24),
                    // Value display
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '${state.randomnessPercentage}%',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getRandomnessLabel(state.randomnessPercentage),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
            // Explanation cards
            _buildExplanationCard(
              context,
              '🎯',
              'Focused',
              'Stick to your favorite genres and artists',
              0,
            ),
            const SizedBox(height: 16),
            _buildExplanationCard(
              context,
              '⚖️',
              'Balanced',
              'Mix of familiar and new music',
              15,
            ),
            const SizedBox(height: 16),
            _buildExplanationCard(
              context,
              '🚀',
              'Adventurous',
              'Explore new genres and artists',
              35,
            ),
            const SizedBox(height: 40),
            // Info box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You can adjust these settings anytime in your preferences.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard(
    BuildContext context,
    String emoji,
    String title,
    String description,
    int percentage,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surfaceContainer,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (percentage <= 15)
                      _buildBadge(context, 'Default')
                    else if (percentage <= 25)
                      _buildBadge(context, 'Popular')
                    else
                      _buildBadge(context, 'Experimental'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _getRandomnessLabel(int percentage) {
    if (percentage <= 5) return 'Very Safe - Highly predictable';
    if (percentage <= 15) return 'Safe - Mostly familiar music';
    if (percentage <= 25) return 'Moderate - Some new discoveries';
    if (percentage <= 35) return 'Adventurous - Lots of new music';
    return 'Very Adventurous - Maximum exploration';
  }



  Widget _buildDesktopExplanationCard(
    BuildContext context,
    String emoji,
    String title,
    String description,
    int percentage,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            width: isSelected ? 2 : 1.5,
          ),
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerLow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isSelected ? theme.colorScheme.primary : null,
                        ),
                      ),
                      if (percentage <= 15)
                        _buildBadge(context, 'Default')
                      else if (percentage <= 25)
                        _buildBadge(context, 'Popular')
                      else
                        _buildBadge(context, 'Experimental'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildDesktopRandomness(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) {
        final percentage = state.randomnessPercentage;

        return LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Column: Header, Description & Info (Static/Fixed)
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          // Visual Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                            ),
                            child: const Center(
                              child: Text(
                                '🚀',
                                style: TextStyle(fontSize: 36),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'Discovery Preferences',
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 32,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'How adventurous do you want your music experience? Adjust this slider to control how Musée balances familiar favorites with new discovery tracks.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: theme.colorScheme.primary.withValues(alpha: 0.08),
                              border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: theme.colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'You can adjust these settings anytime in your preferences.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                  // Right Column: Slider and explanation cards (Scrollable)
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          // Giant visual feedback container
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '${state.randomnessPercentage}%',
                                  style: theme.textTheme.displayMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _getRandomnessLabel(state.randomnessPercentage),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Slider(
                                  value: state.randomnessPercentage.toDouble(),
                                  min: 0,
                                  max: 50,
                                  divisions: 50,
                                  onChanged: (value) {
                                    context.read<OnboardingBloc>().add(
                                      UpdateRandomnessEvent(value.toInt()),
                                    );
                                  },
                                  activeColor: theme.colorScheme.primary,
                                  inactiveColor: theme.colorScheme.surfaceContainerHighest,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildDesktopExplanationCard(
                            context,
                            '🎯',
                            'Focused',
                            'Stick to your favorite genres and artists',
                            0,
                            percentage == 0,
                            () {
                              context.read<OnboardingBloc>().add(
                                const UpdateRandomnessEvent(0),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildDesktopExplanationCard(
                            context,
                            '⚖️',
                            'Balanced',
                            'Mix of familiar and new music',
                            15,
                            percentage == 15,
                            () {
                              context.read<OnboardingBloc>().add(
                                const UpdateRandomnessEvent(15),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildDesktopExplanationCard(
                            context,
                            '🚀',
                            'Adventurous',
                            'Explore new genres and artists',
                            35,
                            percentage == 35,
                            () {
                              context.read<OnboardingBloc>().add(
                                const UpdateRandomnessEvent(35),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
