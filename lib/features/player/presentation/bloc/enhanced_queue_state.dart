part of 'enhanced_queue_bloc.dart';

abstract class EnhancedQueueState extends Equatable {
  const EnhancedQueueState();

  @override
  List<Object?> get props => [];
}

class QueueInitial extends EnhancedQueueState {
  const QueueInitial();
}

class QueueLoading extends EnhancedQueueState {
  const QueueLoading();
}

class QueueLoaded extends EnhancedQueueState {
  final List<String> queue;
  final DateTime? lastSmartFilled;

  const QueueLoaded({
    required this.queue,
    this.lastSmartFilled,
  });

  @override
  List<Object?> get props => [queue, lastSmartFilled];
}

class QueuePreferencesUpdated extends EnhancedQueueState {
  final QueuePreferences preferences;

  const QueuePreferencesUpdated({required this.preferences});

  @override
  List<Object?> get props => [preferences];
}

class QueueSmartFillError extends EnhancedQueueState {
  final String message;
  // Queue still remains loaded even on fill error

  const QueueSmartFillError(this.message);

  @override
  List<Object?> get props => [message];
}

class TrackSkipped extends EnhancedQueueState {
  final String trackId;
  final int atSeconds;

  const TrackSkipped({
    required this.trackId,
    required this.atSeconds,
  });

  @override
  List<Object?> get props => [trackId, atSeconds];
}

class QueueError extends EnhancedQueueState {
  final String message;

  const QueueError(this.message);

  @override
  List<Object?> get props => [message];
}
