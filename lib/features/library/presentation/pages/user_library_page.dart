import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class UserLibraryPage extends StatelessWidget {
  const UserLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Your Library')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // ── Downloads ───────────────────────────────────────────
          _LibraryTile(
            onTap: () => context.push('/library/downloads'),
            icon: Icons.download_rounded,
            gradient: LinearGradient(
              colors: [Colors.purple.shade800, Colors.blue.shade800],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            title: 'Downloads',
            subtitle: 'Tracks available for offline playback',
          ),

          const Divider(indent: 16, endIndent: 16),

          // ── Liked Songs ─────────────────────────────────────────
          _LibraryTile(
            onTap: () => context.push('/library/liked-songs'),
            icon: Icons.favorite_rounded,
            gradient: LinearGradient(
              colors: [
                const Color(0xFF4A148C),
                cs.primary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            title: 'Liked Songs',
            subtitle: 'Tracks you\'ve saved to your favourites',
          ),
        ],
      ),
    );
  }
}

class _LibraryTile extends StatelessWidget {
  final VoidCallback onTap;
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String subtitle;

  const _LibraryTile({
    required this.onTap,
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
