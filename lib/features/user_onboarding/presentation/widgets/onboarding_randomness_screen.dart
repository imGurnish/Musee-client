import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';

class OnboardingRandomnessScreen extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingRandomnessScreen({
    Key? key,
    required this.onNext,
  }) : super(key: key);

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
                color: Colors.grey[600],
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
                      inactiveColor: Colors.grey[300],
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
                              color: Colors.grey[600],
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
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
        border: Border.all(color: Colors.grey[300]!),
        color: Colors.grey[50],
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
                    color: Colors.grey[600],
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
        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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
}
