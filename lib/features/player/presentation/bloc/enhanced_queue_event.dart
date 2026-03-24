part of 'enhanced_queue_bloc.dart';

abstract class EnhancedQueueEvent extends Equatable {
  const EnhancedQueueEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize queue on app startup
class InitializeEnhancedQueueEvent extends EnhancedQueueEvent {
  const InitializeEnhancedQueueEvent();
}

/// Add tracks to queue
class AddTracksToQueueEvent extends EnhancedQueueEvent {
  final List<String> trackIds;
  final int? position; // Insert at position, null = append

  const AddTracksToQueueEvent({
    required this.trackIds,
    this.position,
  });

  @override
  List<Object?> get props => [trackIds, position];
}

/// Remove track from queue
class RemoveTrackFromQueueEvent extends EnhancedQueueEvent {
  final String trackId;

  const RemoveTrackFromQueueEvent(this.trackId);

  @override
  List<Object?> get props => [trackId];
}

/// Reorder queue
class ReorderQueueEvent extends EnhancedQueueEvent {
  final int fromIndex;
  final int toIndex;

  const ReorderQueueEvent({
    required this.fromIndex,
    required this.toIndex,
  });

  @override
  List<Object?> get props => [fromIndex, toIndex];
}

/// Smart fill queue with recommendations
class SmartFillQueueEvent extends EnhancedQueueEvent {
  final String recommendationType; // 'discovery', 'similar_to_liked', 'trending', 'mood_based'
  final int limit; // How many tracks to add
  final UserOnboardingPreferences? userPreferences;

  const SmartFillQueueEvent({
    this.recommendationType = 'discovery',
    this.limit = 20,
    this.userPreferences,
  });

  @override
  List<Object?> get props => [recommendationType, limit, userPreferences];
}

/// Update queue preferences for smart fill
class UpdateQueuePreferencesEvent extends EnhancedQueueEvent {
  final QueuePreferences preferences;

  const UpdateQueuePreferencesEvent(this.preferences);

  @override
  List<Object?> get props => [preferences];
}

/// Prioritize a specific track
class PrioritizeTrackEvent extends EnhancedQueueEvent {
  final String trackId;
  final int? position; // Position to move to (default: 1)

  const PrioritizeTrackEvent(
    this.trackId, {
    this.position,
  });

  @override
  List<Object?> get props => [trackId, position];
}

/// Skip track
class SkipTrackEvent extends EnhancedQueueEvent {
  final String trackId;
  final int atSeconds;

  const SkipTrackEvent({
    required this.trackId,
    required this.atSeconds,
  });

  @override
  List<Object?> get props => [trackId, atSeconds];
}


