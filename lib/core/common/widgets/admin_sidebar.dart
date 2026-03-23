import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/navigation/routes.dart';

class AdminSidebar extends StatelessWidget {
  final void Function(String key)? onSelect;

  const AdminSidebar({super.key, this.onSelect});

  Widget _item(BuildContext context, IconData icon, String label, String key) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () {
          if (onSelect != null) {
            onSelect!(key);
          } else {
            context.go(key);
          }
        },
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: const Text(
              'Admin',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          // Admin Home
          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('Admin Home'),
            onTap: () => GoRouter.of(context).go(Routes.adminDashboard),
          ),
          const Divider(height: 1),
          _item(context, Icons.people, 'Users', '/admin/users'),
          _item(context, Icons.mic, 'Artists', '/admin/artists'),
          _item(context, Icons.album, 'Albums', '/admin/albums'),
          _item(context, Icons.queue_music, 'Playlists', Routes.adminPlaylists),
          _item(context, Icons.subscriptions, 'Plans', '/admin/plans'),
          _item(context, Icons.public, 'Countries', '/admin/countries'),
          _item(context, Icons.map, 'Regions', '/admin/regions'),
          _item(context, Icons.music_note, 'Tracks', '/admin/tracks'),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.dashboard_customize),
            title: const Text('Open user dashboard'),
            onTap: () => GoRouter.of(context).go(Routes.dashboard),
          ),
        ],
      ),
    );
  }
}
