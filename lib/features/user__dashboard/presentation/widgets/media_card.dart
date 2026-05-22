import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/core/common/widgets/playing_bars_animation.dart';

class MediaCard extends StatelessWidget {
  final String? id;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? localImagePath;
  final IconData fallbackIcon;
  final String mediaTypeLabel;
  final bool isCached;
  final double borderRadius;
  final VoidCallback? onTap;

  const MediaCard({
    super.key,
    this.id,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.localImagePath,
    this.fallbackIcon = Icons.music_note,
    this.mediaTypeLabel = 'Track',
    this.isCached = false,
    this.borderRadius = 12,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(borderRadius),
      child: Ink(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: BlocBuilder<PlayerCubit, PlayerViewState>(
                    builder: (context, state) {
                      final type = mediaTypeLabel.toLowerCase();
                      bool isActive = false;
                      if (id != null) {
                        if (type == 'album') {
                          isActive = state.track?.albumId == id;
                        } else if (type == 'playlist') {
                          isActive = state.track?.playlistId == id;
                        } else if (type == 'artist') {
                          isActive = state.track?.artistId == id;
                        } else {
                          isActive = state.track?.trackId == id;
                        }
                      }
                      final isPlaying = isActive && state.playing;

                      return Stack(
                        children: [
                          Positioned.fill(
                            child: _buildImageOrPlaceholder(color),
                          ),
                          if (isActive)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.3),
                                child: Center(
                                  child: ClipOval(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            width: 1,
                                          ),
                                        ),
                                        child: Center(
                                          child: PlayingBarsAnimation(
                                            width: 24,
                                            height: 24,
                                            barCount: 4,
                                            barWidth: 3,
                                            gap: 2,
                                            color: Colors.white,
                                            isPlaying: isPlaying,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withValues(
                          alpha: 0.78,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TinyMetaIcon(
                    icon: _typeIcon(),
                    color: color.onSurface.withValues(alpha: 0.65),
                  ),
                  const SizedBox(width: 6),
                  _TinyMetaIcon(
                    icon: isCached
                        ? Icons.download_done_rounded
                        : Icons.wifi_rounded,
                    color: isCached
                        ? Colors.green.shade600
                        : color.onSurface.withValues(alpha: 0.65),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _typeIcon() {
    final type = mediaTypeLabel.toLowerCase();
    if (type == 'album') return Icons.album_rounded;
    if (type == 'playlist') return Icons.queue_music_rounded;
    return Icons.music_note_rounded;
  }

  Widget _buildImageOrPlaceholder(ColorScheme color) {
    if (localImagePath != null && File(localImagePath!).existsSync()) {
      return Image.file(
        File(localImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildNetworkOrPlaceholder(color),
      );
    }
    return _buildNetworkOrPlaceholder(color);
  }

  Widget _buildNetworkOrPlaceholder(ColorScheme color) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(imageUrl!, fit: BoxFit.cover);
    }
    return Container(
      color: color.primaryContainer.withValues(alpha: 0.4),
      child: Center(child: Icon(fallbackIcon, size: 36)),
    );
  }
}

class _TinyMetaIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _TinyMetaIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 14, color: color),
    );
  }
}
