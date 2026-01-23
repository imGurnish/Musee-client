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
          onSelect?.call(key);
          Navigator.of(context).maybePop();
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
          _item(context, Icons.people, 'Users', 'users'),
          _item(context, Icons.mic, 'Artists', 'artists'),
          _item(context, Icons.album, 'Albums', 'albums'),
          _item(context, Icons.queue_music, 'Playlists', 'playlists'),
          _item(context, Icons.subscriptions, 'Plans', 'plans'),
          _item(context, Icons.public, 'Countries', 'countries'),
          _item(context, Icons.map, 'Regions', 'regions'),
          _item(context, Icons.music_note, 'Tracks', 'tracks'),
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
