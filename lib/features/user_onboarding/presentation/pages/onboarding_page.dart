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

  const OnboardingPage({
    Key? key,
    required this.userId,
    this.onCompleted,
  }) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _currentStep = 0;
  late PageController _pageController;

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
    return BlocListener<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
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
        body: SafeArea(
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
        ),
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
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 6,
              minHeight: 6,
              backgroundColor: Colors.grey[300],
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
