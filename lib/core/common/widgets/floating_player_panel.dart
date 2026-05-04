import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/features/listening_history/data/repositories/listening_history_repository.dart';

class FloatingPlayerPanel extends StatefulWidget {
  const FloatingPlayerPanel({super.key});

  @override
  State<FloatingPlayerPanel> createState() => _FloatingPlayerPanelState();
}

class _FloatingPlayerPanelState extends State<FloatingPlayerPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  double _dragDx = 0;
  bool _swiping = false;

  /// Direction the content is sliding out: -1 = left (next), 1 = right (prev)
  int _slideDirection = 0;

  static const double _swipeThreshold = 40;
  static const Duration _slideDuration = Duration(milliseconds: 250);

  bool _isTrackLiked = false;
  String? _likedTrackId;
  StreamSubscription<int>? _trackPreferenceSubscription;

  /// Track ID whose adjacent images we've already precached.
  String? _lastPrecachedForTrackId;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: _slideDuration,
    );
  }

  @override
  void dispose() {
    _trackPreferenceSubscription?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  void _subscribeTrackPreference(String? trackId) {
    if (trackId == null || trackId.isEmpty || trackId == _likedTrackId) {
      return;
    }

    _trackPreferenceSubscription?.cancel();
    _likedTrackId = trackId;
    _isTrackLiked = false;

    final repo = GetIt.I<ListeningHistoryRepository>();
    _trackPreferenceSubscription = repo.watchTrackPreference(trackId).listen((pref) {
      final liked = pref == 1;
      if (mounted && _likedTrackId == trackId && liked != _isTrackLiked) {
        setState(() => _isTrackLiked = liked);
      }
    });

    unawaited(repo.getTrackPreference(trackId));
  }

  /// Precache artwork images for the next and previous queue items so that
  /// they are instantly available when the user swipes.
  void _preloadAdjacentImages(BuildContext context, PlayerViewState state) {
    final currentTrackId = state.track?.trackId;
    if (currentTrackId == null || currentTrackId == _lastPrecachedForTrackId) {
      return;
    }
    _lastPrecachedForTrackId = currentTrackId;

    final queue = state.queue;
    final idx = state.currentIndex;
    if (queue.isEmpty || idx < 0) return;

    void precacheAt(int queueIndex) {
      if (queueIndex < 0 || queueIndex >= queue.length) return;
      final item = queue[queueIndex];
      if (item.localImagePath != null) {
        precacheImage(FileImage(File(item.localImagePath!)), context);
      } else if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        precacheImage(NetworkImage(item.imageUrl!), context);
      }
    }

    precacheAt(idx - 1);
    precacheAt(idx + 1);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) {
    if (_swiping) return;
    setState(() => _dragDx += d.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails d) {
    if (_swiping) return;
    final cubit = GetIt.I<PlayerCubit>();
    final canControl = cubit.state.track != null || cubit.state.playing;
    if (!canControl) {
      setState(() => _dragDx = 0);
      return;
    }

    if (_dragDx.abs() > _swipeThreshold) {
      final goNext = _dragDx < 0;
      _triggerSlide(goNext ? -1 : 1, cubit);
    } else {
      setState(() => _dragDx = 0);
    }
  }

  Future<void> _triggerSlide(int direction, PlayerCubit cubit) async {
    _swiping = true;
    _slideDirection = direction;
    _dragDx = 0;

    // Phase 1: slide current content out
    _slideController.value = 0;
    await _slideController.forward();

    // Fire track change
    if (direction < 0) {
      cubit.next(userInitiated: true);
    } else {
      cubit.previous();
    }

    // Wait for BlocBuilder to pick up the new track metadata so the
    // slide-in animation shows the correct (new) content.
    await Future<void>.delayed(Duration.zero);
    if (mounted) {
      await WidgetsBinding.instance.endOfFrame;
    }

    // Phase 2: slide new content in from opposite side
    _slideDirection = -direction;
    _slideController.value = 1;
    await _slideController.reverse();

    _swiping = false;
    _slideDirection = 0;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final cubit = GetIt.I<PlayerCubit>();

    void toggleTrackLike() {
      final trackId = _likedTrackId;
      if (trackId == null) return;
      final repo = GetIt.I<ListeningHistoryRepository>();
      final nextLiked = !_isTrackLiked;
      setState(() => _isTrackLiked = nextLiked);
      if (nextLiked) {
        unawaited(repo.likeTrack(trackId));
      } else {
        unawaited(repo.clearTrackPreference(trackId));
      }
    }

    return BlocBuilder<PlayerCubit, PlayerViewState>(
      bloc: cubit,
      builder: (context, state) {
        final track = state.track;
        final hasTrack = track != null;
        final showingLoading =
          state.buffering || state.isTransitioning || state.resolvingUrl;
        final canControlPlayback = hasTrack || state.playing;
        final title = track?.title ?? 'Nothing playing';
        final artist = track?.artist ?? 'Tap to choose something';
        final subtitleText = artist;
        final subtitleColor = theme.textTheme.bodySmall?.color?.withValues(alpha: 0.8);

        // Precache adjacent track images for smooth swipe transitions.
        _preloadAdjacentImages(context, state);

        // Keep this panel in sync with shared like preference state.
        _subscribeTrackPreference(track?.trackId);

        final pos = state.position;
        final dur = state.duration;
        final progress = (dur.inMilliseconds > 0)
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          child: InkWell(
          onTap: hasTrack
              ? () {
                  final t = track; // non-null under hasTrack
                  showPlayerBottomSheet(
                    context,
                    audioUrl: t.url,
                    title: t.title,
                    artist: t.artist,
                    album: t.album,
                    imageUrl: t.imageUrl,
                    localImagePath: t.localImagePath,
                    headers: t.headers,
                    trackId: t.trackId,
                  );
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: color.surfaceContainerHighest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Content row: artwork • title/artist • controls
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: AnimatedBuilder(
                    animation: _slideController,
                    builder: (context, child) {
                      final double dx;
                      final double opacity;
                      if (_swiping) {
                        final t = Curves.easeInOutCubic
                            .transform(_slideController.value);
                        dx = _slideDirection *
                            t *
                            MediaQuery.of(context).size.width * 0.3;
                        opacity = (1 - t).clamp(0.3, 1.0);
                      } else {
                        dx = _dragDx * 0.35; // dampened drag follow
                        opacity = 1.0;
                      }
                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(dx, 0),
                          child: child,
                        ),
                      );
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Artwork
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: _buildArtwork(
                              track?.imageUrl,
                              track?.localImagePath,
                              color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Title / Artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitleText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: subtitleColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Controls
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Like button (compact)
                            if (hasTrack && track.trackId != null)
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  tooltip: _isTrackLiked ? 'Unlike' : 'Like',
                                  onPressed: toggleTrackLike,
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 200),
                                    transitionBuilder: (child, anim) =>
                                        FadeTransition(opacity: anim, child: child),
                                    child: Icon(
                                      _isTrackLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      key: ValueKey(_isTrackLiked),
                                      color: _isTrackLiked
                                          ? Colors.redAccent
                                          : theme.colorScheme.onSurfaceVariant,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: canControlPlayback
                                    ? () => cubit.previous()
                                    : null,
                                tooltip: 'Previous',
                                icon: const Icon(Icons.skip_previous_rounded, size: 22),
                              ),
                            ),
                            SizedBox(
                              width: 38,
                              height: 38,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: const CircleBorder(),
                                ),
                                onPressed: canControlPlayback
                                    ? () => cubit.togglePlayPause()
                                    : null,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: state.playing
                                      ? const Icon(
                                          Icons.pause_rounded,
                                          key: ValueKey('pause'),
                                          size: 22,
                                        )
                                      : showingLoading
                                      ? _PlayButtonLoader(
                                          key: const ValueKey('loading'),
                                          compact: true,
                                          resolving: state.resolvingUrl,
                                        )
                                      : const Icon(
                                          Icons.play_arrow_rounded,
                                          key: ValueKey('play'),
                                          size: 26,
                                        ),
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 36,
                              height: 36,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                onPressed: canControlPlayback
                                    ? () => cubit.next(userInitiated: true)
                                    : null,
                                tooltip: 'Next',
                                icon: const Icon(Icons.skip_next_rounded, size: 22),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Progress bar — thin line at the bottom
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2.5,
                  backgroundColor: color.onSurface.withValues(
                    alpha: 0.10,
                  ),
                  valueColor: AlwaysStoppedAnimation(color.primary),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  Widget _buildArtwork(String? imageUrl, String? localPath, ColorScheme color) {
    if (localPath != null && File(localPath).existsSync()) {
      return Image.file(File(localPath), fit: BoxFit.cover);
    }
    if (imageUrl != null) {
      return Image.network(imageUrl, fit: BoxFit.cover);
    }
    return Container(
      color: color.primaryContainer.withValues(alpha: 0.4),
      child: const Icon(Icons.music_note, size: 28),
    );
  }
}

class _PlayButtonLoader extends StatelessWidget {
  final bool compact;
  final bool resolving;

  const _PlayButtonLoader({
    super.key,
    required this.compact,
    required this.resolving,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spinnerSize = compact ? 22.0 : 42.0;
    final iconSize = compact ? 12.0 : 20.0;
    return SizedBox(
      width: spinnerSize,
      height: spinnerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: compact ? 2.4 : 3.0,
            color: theme.colorScheme.onPrimary,
          ),
          Icon(
            resolving ? Icons.cloud_sync_rounded : Icons.graphic_eq_rounded,
            size: iconSize,
            color: theme.colorScheme.onPrimary,
          ),
        ],
      ),
    );
  }
}

