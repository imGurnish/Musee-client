import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/onboarding_bloc.dart';
import '../widgets/onboarding_welcome_screen.dart';
import '../widgets/onboarding_language_screen.dart';
import '../widgets/onboarding_genre_screen.dart';
import '../widgets/onboarding_mood_screen.dart';
import '../widgets/onboarding_artist_screen.dart';
import '../widgets/onboarding_randomness_screen.dart';

class OnboardingPage extends StatefulWidget {
  final String userId;
  final Function(BuildContext)? onCompleted;
  /// When true, existing preferences are loaded so the user sees current selections.
  final bool isEditing;

  const OnboardingPage({
    super.key,
    required this.userId,
    this.onCompleted,
    this.isEditing = false,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 0;
  late PageController _pageController;
  bool _preferencesFetched = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Initialize onboarding data
    context.read<OnboardingBloc>().add(const InitializeOnboardingEvent());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextStep() {
    if (_currentStep < 5) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _completeOnboarding() {
    context.read<OnboardingBloc>().add(SavePreferencesEvent(widget.userId));
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        // Once genres/moods are loaded (init done) and editing, fetch prefs once
        if (widget.isEditing &&
            !_preferencesFetched &&
            !state.isLoading &&
            state.genres.isNotEmpty) {
          _preferencesFetched = true;
          context
              .read<OnboardingBloc>()
              .add(FetchUserPreferencesEvent(widget.userId));
        }
        if (state.isCompleted) {
          widget.onCompleted?.call(context);
          // Navigate away from onboarding
          Navigator.of(context).pop();
        }
        if (state.error != null && state.error!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!)),
          );
        }
      },
      child: Scaffold(
        body: isDesktop ? _buildDesktopLayout(context) : _buildMobileLayout(context),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Progress indicator
          _buildProgressBar(),
          // Page view for screens
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentStep = index);
              },
              children: [
                OnboardingWelcomeScreen(onNext: _goToNextStep),
                OnboardingLanguageScreen(onNext: _goToNextStep),
                OnboardingGenreScreen(onNext: _goToNextStep),
                OnboardingMoodScreen(onNext: _goToNextStep),
                OnboardingArtistScreen(onNext: _goToNextStep),
                OnboardingRandomnessScreen(
                  onNext: _completeOnboarding,
                ),
              ],
            ),
          ),
          // Bottom navigation
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // Calculate dimensions for the centered card
    final cardWidth = size.width * 0.75 > 980 ? 980.0 : size.width * 0.75;
    final cardHeight = size.height * 0.85 > 780 ? 780.0 : size.height * 0.85;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
      ),
      child: Stack(
        children: [
          // Ambient blurred gradient elements
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -100,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.secondary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Container(color: Colors.transparent),
            ),
          ),
          // Centered main content card
          Center(
            child: Container(
              width: cardWidth,
              height: cardHeight,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 24.0),
                  child: Column(
                    children: [
                      // Progress indicator
                      _buildProgressBar(),
                      const SizedBox(height: 16),
                      // Page view for screens
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          onPageChanged: (index) {
                            setState(() => _currentStep = index);
                          },
                          children: [
                            OnboardingWelcomeScreen(onNext: _goToNextStep),
                            OnboardingLanguageScreen(onNext: _goToNextStep),
                            OnboardingGenreScreen(onNext: _goToNextStep),
                            OnboardingMoodScreen(onNext: _goToNextStep),
                            OnboardingArtistScreen(onNext: _goToNextStep),
                            OnboardingRandomnessScreen(
                              onNext: _completeOnboarding,
                            ),
                          ],
                        ),
                      ),
                      // Bottom navigation
                      _buildBottomNavigation(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step counter
          Text(
            'Step ${_currentStep + 1} of 6',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 6,
              minHeight: 6,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigation() {
    return BlocBuilder<OnboardingBloc, OnboardingState>(
      builder: (context, state) {
        final isLastStep = _currentStep == 5;
        final isFirstStep = _currentStep == 0;

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              if (!isFirstStep)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goToPreviousStep,
                    child: const Text('Back'),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: state.isSaving ? null : (isLastStep ?_completeOnboarding : _goToNextStep),
                  child: state.isSaving
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text(isLastStep ? 'Complete' : 'Next'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
