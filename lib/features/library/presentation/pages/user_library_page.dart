import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';
import 'package:musee/init_dependencies.dart';

class UserLibraryPage extends StatefulWidget {
  const UserLibraryPage({super.key});

  @override
  State<UserLibraryPage> createState() => _UserLibraryPageState();
}

class _UserLibraryPageState extends State<UserLibraryPage> {
  late Future<List<UserPlaylistDetail>> _playlistsFuture;

  @override
  void initState() {
    super.initState();
    _refreshPlaylists();
  }

  void _refreshPlaylists() {
    setState(() {
      _playlistsFuture = serviceLocator<UserPlaylistsRepository>()
          .getPlaylists();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Your Library',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        actions: [
          // Elegant Add button to create playlists
          IconButton(
            icon: const Icon(CupertinoIcons.add, size: 24),
            tooltip: 'Create Playlist',
            onPressed: () async {
              await context.push('/create');
              // Refresh when returning back
              _refreshPlaylists();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshPlaylists();
          await _playlistsFuture.catchError((_) => <UserPlaylistDetail>[]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            // ── Downloads ───────────────────────────────────────────
            _LibraryTile(
              onTap: () => context.push('/library/downloads'),
              icon: CupertinoIcons.arrow_down_circle_fill,
              gradient: LinearGradient(
                colors: [Colors.purple.shade800, Colors.blue.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              title: 'Downloads',
              subtitle: 'Tracks available for offline playback',
            ),

            const Divider(indent: 16, endIndent: 16, height: 16),

            // ── Liked Songs ─────────────────────────────────────────
            _LibraryTile(
              onTap: () => context.push('/library/liked-songs'),
              icon: CupertinoIcons.heart_fill,
              gradient: LinearGradient(
                colors: [const Color(0xFF4A148C), cs.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              title: 'Liked Songs',
              subtitle: 'Tracks you\'ve saved to your favourites',
            ),

            const Divider(indent: 16, endIndent: 16, height: 24),

            // ── User Playlists Section Header ────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Playlists',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await context.push('/create');
                      _refreshPlaylists();
                    },
                    icon: const Icon(CupertinoIcons.plus, size: 14),
                    label: const Text('Create', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),

            // ── Playlists FutureBuilder ──────────────────────────────
            FutureBuilder<List<UserPlaylistDetail>>(
              future: _playlistsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: CupertinoActivityIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.exclamationmark_triangle,
                            size: 36,
                            color: cs.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Failed to load playlists',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            snapshot.error.toString().replaceAll(
                              'Exception: ',
                              '',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _refreshPlaylists,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final playlists = snapshot.data ?? [];
                if (playlists.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 48.0,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            CupertinoIcons.music_note_list,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No playlists yet',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create private or collaborative playlists to start listening together!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () async {
                              await context.push('/create');
                              _refreshPlaylists();
                            },
                            icon: const Icon(CupertinoIcons.plus, size: 16),
                            label: const Text('Create Playlist'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    final trackCount = playlist.totalTracks > 0
                        ? playlist.totalTracks
                        : playlist.tracks.length;
                    final creatorName = playlist.artists.isNotEmpty
                        ? (playlist.artists.first.name ?? 'Unknown')
                        : 'Unknown';

                    return ListTile(
                      onTap: () async {
                        final result = await context.push('/playlists/${playlist.playlistId}');
                        if (result == true) _refreshPlaylists();
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 52,
                          height: 52,
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: playlist.coverUrl != null
                              ? Image.network(
                                  playlist.coverUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    CupertinoIcons.music_note_list,
                                    size: 24,
                                    color: Colors.white30,
                                  ),
                                )
                              : const Icon(
                                  CupertinoIcons.music_note_list,
                                  size: 24,
                                  color: Colors.white30,
                                ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              playlist.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (playlist.isCollaborative) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1DB954,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(
                                    0xFF1DB954,
                                  ).withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.person_3_fill,
                                    size: 10,
                                    color: Color(0xFF1DB954),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'COLLAB',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1DB954),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          '$trackCount tracks • By $creatorName',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 16,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
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
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
      onTap: onTap,
    );
  }
}
