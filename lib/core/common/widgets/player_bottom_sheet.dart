import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';

bool _isPlayerSheetOpen = false;
DateTime? _lastPlayerSheetOpenAt;

/// Shows the full-screen player bottom sheet, styled similar to Spotify.
Future<void> showPlayerBottomSheet(
  BuildContext context, {
  String? audioUrl,
  required String title,
  required String artist,
  String? album,
  String? imageUrl,
  String? localImagePath,
  Map<String, String>? headers,
  String? trackId,
  bool openSheet = true,
}) async {
  final cubit = GetIt.I<PlayerCubit>();

  Future<void> requestPlaybackSwitch() async {
    try {
      Future<void> ensureAutoPlay() async {
        final s = cubit.state;
        if (cubit.isUserPausedIntent) return;
        if (!s.playing && !s.buffering && s.track != null) {
          await cubit.ensurePlaying();
        }
      }

      if (trackId != null && (audioUrl == null || audioUrl.isEmpty)) {
        await cubit.playTrackById(
          trackId: trackId,
          title: title,
          artist: artist,
          album: album,
          imageUrl: imageUrl,
        );
        return;
      }

      if (audioUrl != null && audioUrl.isNotEmpty) {
        final track = PlayerTrack(
          url: audioUrl,
          title: title,
          artist: artist,
          album: album,
          imageUrl: imageUrl,
          localImagePath: localImagePath,
          headers: headers,
          trackId: trackId,
        );

        final currentUrl = cubit.state.track?.url;
        final isDifferentTrack = currentUrl == null || currentUrl != audioUrl;
        if (isDifferentTrack) {
          await cubit.playTrack(track);
        } else {
          await ensureAutoPlay();
        }
      }
    } catch (_) {
      // Player cubit already emits user-facing errors; avoid crashing UI tap flow.
    }
  }

  if (!openSheet) {
    await requestPlaybackSwitch();
    return;
  }

  if (_isPlayerSheetOpen) {
    unawaited(requestPlaybackSwitch());
    return;
  }

  final now = DateTime.now();
  if (_lastPlayerSheetOpenAt != null &&
      now.difference(_lastPlayerSheetOpenAt!) < const Duration(milliseconds: 500)) {
    unawaited(requestPlaybackSwitch());
    return;
  }

  _isPlayerSheetOpen = true;
  _lastPlayerSheetOpenAt = now;

  try {
    // Dispatch playback request asynchronously so modal opening is never blocked
    // by network URL resolution or audio source setup.
    unawaited(requestPlaybackSwitch());

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BlocProvider.value(
          value: cubit,
          child: const _PlayerBackdrop(child: _PlayerSheetBody()),
        );
      },
    );
  } finally {
    _isPlayerSheetOpen = false;
  }
}

/// Backdrop with a subtle vertical gradient based on theme.
class _PlayerBackdrop extends StatelessWidget {
  final Widget child;
  const _PlayerBackdrop({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final top = Color.alphaBlend(
      cs.primary.withValues(alpha: 0.08),
      cs.surface,
    );
    final mid = Color.alphaBlend(
      cs.secondary.withValues(alpha: 0.06),
      cs.surface,
    );
    final bottom = cs.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, mid, bottom],
        ),
      ),
      child: child,
    );
  }
}

class _PlayerSheetBody extends StatefulWidget {
  const _PlayerSheetBody();

  @override
  State<_PlayerSheetBody> createState() => _PlayerSheetBodyState();
}

class _PlayerSheetBodyState extends State<_PlayerSheetBody> {
  String _fmt(Duration d) {
    final total = d.inSeconds;
    final m = (total ~/ 60).toString();
    final sec = (total % 60).toString().padLeft(2, '0');
    return "$m:$sec";
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).viewPadding.top;
    final topGap = topInset > 0
        ? 12.0
        : 0.0; // extra breathing room under notches/dynamic island

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BlocBuilder<PlayerCubit, PlayerViewState>(
        builder: (context, state) {
          final theme = Theme.of(context);
          final showingLoading =
              state.buffering || state.resolvingUrl || state.isTransitioning;
          final canControlPlayback = state.track != null || state.playing;
          final title = state.track?.title ?? 'Unknown Title';
          final artist = state.track?.artist ?? 'Unknown Artist';
            final subtitleText = artist;
            final subtitleColor =
              theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.85);
          final album = state.track?.album ?? '';
          final imageUrl = state.track?.imageUrl;
          final pos = state.position;
          final dur = state.duration.inMilliseconds > 0
              ? state.duration
              : const Duration(seconds: 1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Automatically add a small dynamic margin below system overlays
              if (topGap > 0) SizedBox(height: topGap),
              // Header
              Row(
                children: [
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          album.isEmpty ? 'NOW PLAYING' : 'PLAYING FROM ALBUM',
                          style: theme.textTheme.labelSmall?.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.labelSmall?.color
                                ?.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          album.isEmpty ? 'Musee' : album,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'More',
                    onPressed: () {},
                    icon: const Icon(Icons.more_vert_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Artwork (large square)
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: ClipRRect(
                          key: ValueKey(
                            '${state.track?.trackId ?? state.track?.url ?? 'none'}:${state.track?.localImagePath ?? state.track?.imageUrl ?? ''}',
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: _buildArtwork(
                            imageUrl: imageUrl,
                            localPath: state.track?.localImagePath,
                            theme: theme,
                          ),
                        ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Title + Add
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitleText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (state.track?.trackId != null)
                    _DownloadButton(trackId: state.track!.trackId!),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    tooltip: 'Add to library',
                    onPressed: () {},
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Progress + times
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 6,
                  ),
                ),
                child: Slider(
                  min: 0,
                  max: dur.inMilliseconds.toDouble(),
                  value: pos.inMilliseconds
                      .clamp(0, dur.inMilliseconds)
                      .toDouble(),
                  onChanged: (v) => context.read<PlayerCubit>().seek(
                    Duration(milliseconds: v.round()),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(pos), style: theme.textTheme.labelMedium),
                  Text(_fmt(dur), style: theme.textTheme.labelMedium),
                ],
              ),

              const SizedBox(height: 8),

              // Controls
              Row(
                children: [
                  IconButton(
                    tooltip: 'Enhance / Shuffle',
                    onPressed: () {},
                    icon: const Icon(Icons.auto_awesome_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Previous',
                    onPressed: canControlPlayback
                        ? () => context.read<PlayerCubit>().previous()
                        : null,
                    icon: const Icon(Icons.skip_previous_rounded),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                          onPressed: canControlPlayback
                            ? () => context.read<PlayerCubit>().togglePlayPause()
                            : null,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: state.playing
                            ? const Icon(
                                Icons.pause_rounded,
                                key: ValueKey('pause'),
                                size: 42,
                              )
                            : showingLoading
                            ? _SheetPlayButtonLoader(
                                key: const ValueKey('loading'),
                                resolving: state.resolvingUrl,
                              )
                            : const Icon(
                                Icons.play_arrow_rounded,
                                key: ValueKey('play'),
                                size: 42,
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Next',
                    onPressed: canControlPlayback
                      ? () =>
                        context.read<PlayerCubit>().next(userInitiated: true)
                      : null,
                    icon: const Icon(Icons.skip_next_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Sleep timer',
                    onPressed: () {},
                    icon: const Icon(Icons.timer_rounded),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Footer actions
              Row(
                children: [
                  IconButton(
                    tooltip: 'Devices',
                    onPressed: () {},
                    icon: const Icon(Icons.cast_rounded),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Share',
                    onPressed: () {},
                    icon: const Icon(Icons.share_rounded),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Lyrics / Queue',
                    onPressed: () {
                      final cubit = context.read<PlayerCubit>();
                      showModalBottomSheet(
                        context: context,
                        useRootNavigator: true,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => BlocProvider.value(
                          value: cubit,
                          child: const _QueueSheet(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.queue_music_rounded),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 4),
            ],
          );
        },
      ),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scroll) {
        return Material(
          color: theme.colorScheme.surface,
          elevation: 8,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Queue',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Clear queue',
                      onPressed: () => context.read<PlayerCubit>().clearQueue(),
                      icon: const Icon(Icons.clear_all_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: BlocBuilder<PlayerCubit, PlayerViewState>(
                    builder: (context, state) {
                      final items = state.queue;
                      final controlsLocked = state.isTransitioning;
                      if (items.isEmpty) {
                        return const Center(child: Text('Your queue is empty'));
                      }
                      return ReorderableListView.builder(
                        scrollController: scroll,
                        itemCount: items.length,
                        onReorder: (from, to) {
                          if (controlsLocked) return;
                          // Flutter uses a different insertion index when moving down
                          final newIndex = to > from ? to - 1 : to;
                          context.read<PlayerCubit>().reorderQueue(
                            from,
                            newIndex,
                          );
                        },
                        itemBuilder: (context, index) {
                          final q = items[index];
                          final playing = index == state.currentIndex;
                          return ListTile(
                            key: ValueKey(q.uid),
                            contentPadding: EdgeInsets.zero,
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (playing)
                                  const SizedBox(
                                    width: 40,
                                    child: Icon(Icons.volume_up_rounded),
                                  )
                                else
                                  SizedBox(
                                    width: 40,
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: theme.textTheme.labelLarge,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: _buildSmallArtwork(
                                      q.imageUrl,
                                      q.localImagePath,
                                      theme,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              q.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              q.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Remove',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: controlsLocked
                                      ? null
                                      : () => context
                                            .read<PlayerCubit>()
                                            .removeFromQueue(q.uid),
                                ),
                                const Icon(Icons.drag_handle_rounded),
                              ],
                            ),
                            onTap: controlsLocked
                                ? null
                                : () => context
                                      .read<PlayerCubit>()
                                      .playFromQueueTrackId(q.trackId),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SheetPlayButtonLoader extends StatelessWidget {
  final bool resolving;
  const _SheetPlayButtonLoader({super.key, required this.resolving});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            color: theme.colorScheme.onPrimary,
          ),
          Icon(
            resolving ? Icons.cloud_sync_rounded : Icons.graphic_eq_rounded,
            size: 20,
            color: theme.colorScheme.onPrimary,
          ),
        ],
      ),
    );
  }
}

Widget _buildSmallArtwork(String? url, String? localPath, ThemeData theme) {
  if (localPath != null && File(localPath).existsSync()) {
    return Image.file(File(localPath), fit: BoxFit.cover);
  }
  if (url != null && url.isNotEmpty) {
    return Image.network(url, fit: BoxFit.cover);
  }
  return Container(
    color: theme.colorScheme.surfaceContainerHighest,
    child: const Icon(Icons.music_note_rounded, size: 20),
  );
}

Widget _buildArtwork({
  String? imageUrl,
  String? localPath,
  required ThemeData theme,
}) {
  if (localPath != null && File(localPath).existsSync()) {
    return Image.file(File(localPath), fit: BoxFit.cover);
  }
  if (imageUrl?.isNotEmpty ?? false) {
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (ctx, err, stack) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(Icons.music_note_rounded, size: 64),
      ),
    );
  }
  return Container(
    color: theme.colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Icon(Icons.music_note_rounded, size: 64),
  );
}

class _DownloadButton extends StatelessWidget {
  final String trackId;
  const _DownloadButton({required this.trackId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadManager, DownloadState>(
      builder: (context, state) {
        final status = state.status[trackId];
        final progress = state.progress[trackId] ?? 0.0;

        if (status == DownloadStatus.downloading) {
          return SizedBox(
            width: 48,
            height: 48,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: CircularProgressIndicator(value: progress, strokeWidth: 3),
            ),
          );
        }

        return FutureBuilder<String?>(
          future: GetIt.I<AudioCacheService>().getLocalAudioPath(trackId),
          builder: (context, snapshot) {
            final isDownloaded = snapshot.data != null;

            if (isDownloaded || status == DownloadStatus.completed) {
              return IconButton(
                tooltip: 'Downloaded',
                icon: Icon(
                  Icons.download_done_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {},
              );
            }

            return IconButton(
              tooltip: 'Download',
              icon: const Icon(Icons.download_rounded),
              onPressed: () {
                context.read<DownloadManager>().addToQueue(trackId);
              },
            );
          },
        );
      },
    );
  }
}
