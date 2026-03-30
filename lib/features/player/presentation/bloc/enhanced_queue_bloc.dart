import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:equatable/equatable.dart';
import '../../data/repositories/player_queue_repository.dart';
import '../../data/models/queue_models.dart';
import '../../../listening_history/data/models/listening_history_models.dart';

part 'enhanced_queue_event.dart';
part 'enhanced_queue_state.dart';

/// Enhanced Queue Bloc with smart recommendations and preference-based management
class EnhancedQueueBloc extends Bloc<EnhancedQueueEvent, EnhancedQueueState> {
  final PlayerQueueRepository queueRepository;
  final AudioPlayer audioPlayer;

  EnhancedQueueBloc({
    required this.queueRepository,
    required this.audioPlayer,
  }) : super(const QueueInitial()) {
    on<InitializeEnhancedQueueEvent>(_onInitializeQueue);
    on<AddTracksToQueueEvent>(_onAddTracksToQueue);
    on<RemoveTrackFromQueueEvent>(_onRemoveTrackFromQueue);
    on<ReorderQueueEvent>(_onReorderQueue);
    on<SmartFillQueueEvent>(_onSmartFillQueue);
    on<UpdateQueuePreferencesEvent>(_onUpdateQueuePreferences);
    on<PrioritizeTrackEvent>(_onPrioritizeTrack);
    on<SkipTrackEvent>(_onSkipTrack);
  }

  /// Initialize queue on app start
  Future<void> _onInitializeQueue(
    InitializeEnhancedQueueEvent event,
    Emitter<EnhancedQueueState> emit,
  ) async {
    emit(const QueueLoading());

    try {
      final queue = await queueRepository.getQueue();
      emit(QueueLoaded(queue: queue));
    } catch (e) {
      emit(QueueError(_getErrorMessage(e)));
    }
  }

  /// Add tracks to queue
  Future<void> _onAddTracksToQueue(
    AddTracksToQueueEvent event,
    Emitter<EnhancedQueueState> emit,
  ) async {
    try {
      // Get current state
      if (state is! QueueLoaded) return;
      
      await queueRepository.addTracksToQueue(event.trackIds);
      
      final updatedQueue = await queueRepository.getQueue();
      emit(QueueLoaded(queue: updatedQueue));
    } catch (e) {
      emit(QueueError(_getErrorMessage(e)));
    }
  }

  /// Remove track from queue
  Future<void> _onRemoveTrackFromQueue(
    RemoveTrackFromQueueEvent event,
    Emitter<EnhancedQueueState> emit,
  ) async {
    try {
      await queueRepository.removeTrackFromQueue(event.trackId);
      
      final updatedQueue = await queueRepository.getQueue();
      emit(QueueLoaded(queue: updatedQueue));
    } catch (e) {
      emit(QueueError(_getErrorMessage(e)));
    }
  }

  /// Reorder queue
  Future<void> _onReorderQueue(
    ReorderQueueEvent event,
    Emitter<EnhancedQueueState> emit,
  ) async {
    try {
      await queueRepository.reorderQueue(event.fromIndex, event.toIndex);
      
      final updatedQueue = await queueRepository.getQueue();
      emit(QueueLoaded(queue: updatedQueue));
    } catch (e) {
      emit(QueueError(_getErrorMessage(e)));
    }
  }

  /// Smart fill queue with recommendations based on user preferences
  /// This is called when queue drops below threshold
  Future<void> _onSmartFillQueue(
    SmartFillQueueEvent event,
    Emitter<EnhancedQueueState> emit,
  ) async {
    try {
      if (state is! QueueLoaded) return;
      
      // Fetch recommendations based on preference
      final recommendations = await queueRepository.getSmartRecommendations(
        type: event.recommendationType,
        limit: event.limit,
        userPreferences: event.userPreferences,
      );

      // Add recommendations to queue
      await queueRepository.addTracksToQueue(recommendations.trackIds);
      
      final updatedQueue = await queueRepository.getQueue();
      emit(QueueLoaded(
        queue: updatedQueue,
        lastSmartFilled: DateTime.now(),
      ));
    } catch (e) {
      // Don't fail the queue on smart fill error, just log it
      emit(QueueSmartFillError(_getErrorMessage(e)));
    }
  }

  /// Update queue preferences
  Future<void> _onUpdateQueuePreferences(
    UpdateQueuePreferencesEvent event,
    Emitter<EnhancedQueueState> emit,
  ) async {
    try {
      await queueRepository.saveQueuePreferences(event.preferences.toJson());
      emit(QueuePreferencesUpdated(preferences: event.preferences));
    } catch (e) {
      emit(QueueError(_getErrorMessage(e)));
    }
  }

  /// Prioritize a specific track (move to front or near front)
  Future<void> _onPrioritizeTrack(
    PrioritizeTrackEvent event,
    Emitter<EnhancedQueueState> emit,
  ) async {
    try {
      if (state is! QueueLoaded) return;
      
      await queueRepository.prioritizeTrack(
        event.trackId,
        event.position ?? 1, // Default: next track
      );
      
      final updatedQueue = await queueRepository.getQueue();
      emit(QueueLoaded(queue: updatedQueue));
    } catch (e) {
      emit(QueueError(_getErrorMessage(e)));
    }
  }

  /// Handle skip - logs skip to listening history
  Future<void> _onSkipTrack(
    SkipTrackEvent event,
    Emitter<EnhancedQueueState> emit,
  ) async {
    try {
      // Skip is handled in player cubit, this is just for logging
      // Dispatch to listening history bloc for logging
      emit(TrackSkipped(
        trackId: event.trackId,
        atSeconds: event.atSeconds,
      ));
    } catch (e) {
      emit(QueueError(_getErrorMessage(e)));
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is Exception) {
      String msg = error.toString();
      if (msg.startsWith('Exception: ')) {
        msg = msg.substring(11);
      }
      return msg;
    }
    return 'An unknown error occurred';
  }
}
