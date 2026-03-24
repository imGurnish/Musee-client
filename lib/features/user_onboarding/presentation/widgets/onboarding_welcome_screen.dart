import 'package:flutter/material.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  final VoidCallback onNext;

  const OnboardingWelcomeScreen({
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
          vertical: isMobile ? 40 : 60,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Large icon/emoji
            Container(
              width: isMobile ? 120 : 160,
              height: isMobile ? 120 : 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              ),
              child: Center(
                child: Text(
                  '🎵',
                  style: TextStyle(
                    fontSize: isMobile ? 60 : 80,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Title
            Text(
              'Welcome to Musée',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Subtitle
            Text(
              'Let\'s personalize your music experience',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            // Description
            Text(
              'We\'ll learn about your taste in music and create customized recommendations tailored just for you.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
                height: 1.6,
              ),
            ),
            const SizedBox(height: 60),
            // Features list
            _buildFeatureItem(
              context,
              '🎯',
              'Personalized Recommendations',
              'Get suggestions based on your taste',
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              context,
              '🎧',
              'Explore New Music',
              'Discover artists and genres you\'ll love',
            ),
            const SizedBox(height: 20),
            _buildFeatureItem(
              context,
              '⚙️',
              'Full Control',
              'Adjust discovery settings anytime',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String emoji,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
