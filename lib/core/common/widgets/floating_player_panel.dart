import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';

class FloatingPlayerPanel extends StatelessWidget {
  const FloatingPlayerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    final cubit = GetIt.I<PlayerCubit>();

    return BlocBuilder<PlayerCubit, PlayerViewState>(
      bloc: cubit,
      builder: (context, state) {
        final track = state.track;
        final hasTrack = track != null;
        final title = track?.title ?? 'Nothing playing';
        final artist = track?.artist ?? 'Tap to choose something';

        final pos = state.position;
        final dur = state.duration;
        final progress = (dur.inMilliseconds > 0)
            ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

        return InkWell(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top row: artwork • title/artist • controls
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Artwork
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 64,
                        height: 64,
                        child: _buildArtwork(
                          track?.imageUrl,
                          track?.localImagePath,
                          color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

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
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Controls
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: hasTrack ? () => cubit.previous() : null,
                          tooltip: 'Previous',
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            onPressed: hasTrack
                                ? (state.buffering
                                      ? null
                                      : () => cubit.togglePlayPause())
                                : null,
                            child: state.playing
                                ? const Icon(Icons.pause_rounded, size: 24)
                                : state.buffering
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 28,
                                  ),
                          ),
                        ),
                        IconButton(
                          onPressed: hasTrack
                              ? () => cubit.next(userInitiated: true)
                              : null,
                          tooltip: 'Next',
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  ],
                ),

                // Progress bar + time codes
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        backgroundColor: color.onSurface.withValues(
                          alpha: 0.12,
                        ),
                        valueColor: AlwaysStoppedAnimation(color.primary),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_fmt(pos), style: theme.textTheme.labelSmall),
                        Text(_fmt(dur), style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ],
                ),
              ],
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

String _fmt(Duration d) {
  final total = d.inSeconds;
  final m = (total ~/ 60).toString();
  final s = (total % 60).toString().padLeft(2, '0');
  return "$m:$s";
}
