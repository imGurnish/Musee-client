import 'package:flutter/material.dart';
import 'package:musee/features/user__dashboard/presentation/widgets/media_card.dart';
import 'package:musee/features/user__dashboard/presentation/widgets/section_header.dart';

class HorizontalMediaSection extends StatelessWidget {
  final String title;
  final List<MediaItem> items;
  final VoidCallback? onSeeAll;
  final double cardWidth;

  const HorizontalMediaSection({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.cardWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title, onSeeAll: onSeeAll),
        SizedBox(
          height: cardWidth + 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: cardWidth,
                child: MediaCard(
                  title: item.title,
                  subtitle: item.subtitle,
                  imageUrl: item.imageUrl,
                  localImagePath: item.localImagePath,
                  fallbackIcon: item.icon,
                  onTap: item.onTap,
                ),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemCount: items.length,
          ),
        ),
      ],
    );
  }
}

class MediaItem {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? localImagePath;
  final IconData icon;
  final VoidCallback? onTap;

  const MediaItem({
    required this.title,
    required this.subtitle,
    this.imageUrl,
    this.localImagePath,
    this.icon = Icons.music_note,
    this.onTap,
  });
}
