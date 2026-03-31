import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:musee/core/common/widgets/admin_sidebar.dart';
import 'package:musee/features/admin__dashboard/presentation/widgets/admin_card.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Open user dashboard',
            onPressed: () => context.go(Routes.dashboard),
            icon: const Icon(Icons.exit_to_app),
          ),
        ],
      ),
      drawer: Drawer(child: AdminSidebar()),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top summary row
                // Top summary row: wraps on small widths to avoid overflow
                LayoutBuilder(
                  builder: (context, topConstraints) {
                    return Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Text(
                          'Welcome back, Admin',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Cards grid
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 290,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 188,
                    ),
                    itemCount: 9,
                    itemBuilder: (context, index) {
                      final cards = [
                        (
                          'Users',
                          'Manage all app users',
                          Icons.people,
                          theme.colorScheme.primary,
                          Routes.adminUsers,
                        ),
                        (
                          'Artists',
                          'Manage artists',
                          Icons.mic,
                          theme.colorScheme.secondary,
                          Routes.adminArtists,
                        ),
                        (
                          'Tracks',
                          'Manage tracks',
                          Icons.music_note,
                          Colors.green,
                          '/admin/tracks',
                        ),
                        (
                          'Albums',
                          'Manage albums',
                          Icons.album,
                          theme.colorScheme.secondary.withValues(alpha: 0.85),
                          '/admin/albums',
                        ),
                        (
                          'Playlists',
                          'Manage playlists',
                          Icons.queue_music,
                          Colors.teal,
                          Routes.adminPlaylists,
                        ),
                        (
                          'JioSaavn Import',
                          'Auto Fetch',
                          Icons.download,
                          Colors.cyan,
                          Routes.adminImport,
                        ),
                        (
                          'Plans',
                          'Manage subscription plans',
                          Icons.subscriptions,
                          Colors.indigo,
                          '/admin/plans',
                        ),
                        (
                          'Countries',
                          'Manage countries',
                          Icons.public,
                          Colors.deepOrange,
                          Routes.adminCountries,
                        ),
                        (
                          'Regions',
                          'Manage regions',
                          Icons.map,
                          Colors.purple,
                          Routes.adminRegions,
                        ),
                      ];

                      final card = cards[index];
                      return AdminCard(
                        title: card.$1,
                        subtitle: card.$2,
                        icon: card.$3,
                        color: card.$4,
                        onTap: () => context.push(card.$5),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// AdminCard moved to widgets/admin_card.dart
