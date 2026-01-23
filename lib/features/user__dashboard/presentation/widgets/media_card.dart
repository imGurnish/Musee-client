import 'dart:io';
import 'package:flutter/material.dart';

class MediaCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? localImagePath;
  final IconData fallbackIcon;
  final double borderRadius;
  final VoidCallback? onTap;

  const MediaCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.localImagePath,
    this.fallbackIcon = Icons.music_note,
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
                  borderRadius: BorderRadius.circular(8),
                  child: _buildImageOrPlaceholder(color),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageOrPlaceholder(ColorScheme color) {
    if (localImagePath != null && File(localImagePath!).existsSync()) {
      return Image.file(
        File(localImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildNetworkOrPlaceholder(color),
      );
    }
    return _buildNetworkOrPlaceholder(color);
  }

  Widget _buildNetworkOrPlaceholder(ColorScheme color) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(imageUrl!, fit: BoxFit.cover);
    }
    return Container(
      color: color.primaryContainer.withOpacity(0.4),
      child: Center(child: Icon(fallbackIcon, size: 36)),
    );
  }
}
