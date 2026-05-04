import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/features/listening_history/data/repositories/listening_history_repository.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';

class LikedSongsPage extends StatefulWidget {
  const LikedSongsPage({super.key});

  @override
  State<LikedSongsPage> createState() => _LikedSongsPageState();
}

class _LikedSongsPageState extends State<LikedSongsPage> {
  List<_LikedTrack> _tracks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = GetIt.I<ListeningHistoryRepository>();
      final raw = await repo.getLikedTracks();
      final parsed = raw
          .map((row) => _LikedTrack.fromRow(row))
          .whereType<_LikedTrack>()
          .toList();
      if (mounted) setState(() => _tracks = parsed);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlike(String trackId) async {
    final repo = GetIt.I<ListeningHistoryRepository>();
    setState(() => _tracks.removeWhere((t) => t.trackId == trackId));
    unawaited(repo.clearTrackPreference(trackId));
  }

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final playerCubit = GetIt.I<PlayerCubit>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 280,
            backgroundColor: cs.surface,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: _LikedSongsHeader(
                trackCount: _tracks.length,
              ),
            ),
            title: const Text('Liked Songs'),
          ),

          // ── Action bar ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  // Play all
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: IconButton.filled(
                      tooltip: 'Play all',
                      onPressed: _tracks.isEmpty
                          ? null
                          : () async {
                              final first = _tracks.first;
                              final queue = _tracks
                                  .map(
                                    (t) => QueueItem(
                                      trackId: t.trackId,
                                      title: t.title,
                                      artist: t.artist,
                                      album: 'Liked Songs',
                                      imageUrl: t.imageUrl,
                                      durationSeconds: t.durationSeconds,
                                    ),
                                  )
                                  .toList();
                              await playerCubit.replaceQueue(queue);
                              if (!context.mounted) return;
                              await showPlayerBottomSheet(
                                context,
                                title: first.title,
                                artist: first.artist,
                                album: 'Liked Songs',
                                imageUrl: first.imageUrl,
                                trackId: first.trackId,
                                openSheet: false,
                              );
                            },
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Shuffle
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: IconButton.outlined(
                      tooltip: 'Shuffle',
                      onPressed: _tracks.isEmpty
                          ? null
                          : () async {
                              final shuffled = [..._tracks]..shuffle();
                              final first = shuffled.first;
                              final queue = shuffled
                                  .map(
                                    (t) => QueueItem(
                                      trackId: t.trackId,
                                      title: t.title,
                                      artist: t.artist,
                                      album: 'Liked Songs',
                                      imageUrl: t.imageUrl,
                                      durationSeconds: t.durationSeconds,
                                    ),
                                  )
                                  .toList();
                              await playerCubit.replaceQueue(queue);
                              if (!context.mounted) return;
                              await showPlayerBottomSheet(
                                context,
                                title: first.title,
                                artist: first.artist,
                                album: 'Liked Songs',
                                imageUrl: first.imageUrl,
                                trackId: first.trackId,
                                openSheet: false,
                              );
                            },
                      icon: const Icon(Icons.shuffle_rounded, size: 19),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_tracks.length} song${_tracks.length == 1 ? '' : 's'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Track list ───────────────────────────────────────────
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 56,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load liked songs',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_tracks.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border_rounded,
                      size: 64,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No liked songs yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap ♡ on any track to save it here',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final t = _tracks[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: Material(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          final queue = _tracks
                              .skip(index)
                              .map(
                                (q) => QueueItem(
                                  trackId: q.trackId,
                                  title: q.title,
                                  artist: q.artist,
                                  album: 'Liked Songs',
                                  imageUrl: q.imageUrl,
                                  durationSeconds: q.durationSeconds,
                                ),
                              )
                              .toList();
                          await playerCubit.replaceQueue(queue);
                          if (!context.mounted) return;
                          await showPlayerBottomSheet(
                            context,
                            title: t.title,
                            artist: t.artist,
                            album: 'Liked Songs',
                            imageUrl: t.imageUrl,
                            trackId: t.trackId,
                            openSheet: false,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // Artwork thumbnail
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: t.imageUrl != null
                                      ? Image.network(
                                          t.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _FallbackArt(cs: cs),
                                        )
                                      : _FallbackArt(cs: cs),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Title + artist
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${t.artist} · ${_fmtDuration(t.durationSeconds)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              // Unlike button
                              IconButton(
                                tooltip: 'Unlike',
                                onPressed: () => _unlike(t.trackId),
                                icon: const Icon(
                                  Icons.favorite_rounded,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                              ),
                              // More
                              IconButton(
                                tooltip: 'More',
                                icon:
                                    const Icon(Icons.more_horiz_rounded),
                                onPressed: () async {
                                  final action =
                                      await showModalBottomSheet<String>(
                                    context: context,
                                    builder: (ctx) => SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.queue_music_rounded,
                                            ),
                                            title: const Text('Add to queue'),
                                            onTap: () =>
                                                Navigator.pop(ctx, 'queue'),
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.favorite_border_rounded,
                                            ),
                                            title: const Text('Unlike'),
                                            onTap: () =>
                                                Navigator.pop(ctx, 'unlike'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                  if (action == 'queue') {
                                    final item = QueueItem(
                                      trackId: t.trackId,
                                      title: t.title,
                                      artist: t.artist,
                                      album: 'Liked Songs',
                                      imageUrl: t.imageUrl,
                                      durationSeconds: t.durationSeconds,
                                    );
                                    await playerCubit.addToQueue([item]);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Added to queue'),
                                        ),
                                      );
                                    }
                                  } else if (action == 'unlike') {
                                    _unlike(t.trackId);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: _tracks.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

// ── Header widget ───────────────────────────────────────────────────────────

class _LikedSongsHeader extends StatelessWidget {
  final int trackCount;
  const _LikedSongsHeader({required this.trackCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4A148C), // deep-purple
            cs.primary.withValues(alpha: 0.85),
            cs.secondary.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big heart icon
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 52,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Liked Songs',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$trackCount song${trackCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fallback artwork ────────────────────────────────────────────────────────

class _FallbackArt extends StatelessWidget {
  final ColorScheme cs;
  const _FallbackArt({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: cs.primaryContainer.withValues(alpha: 0.4),
      child: Icon(Icons.music_note, size: 22, color: cs.onPrimaryContainer),
    );
  }
}

// ── Data model ──────────────────────────────────────────────────────────────

class _LikedTrack {
  final String trackId;
  final String title;
  final String artist;
  final String? imageUrl;
  final int durationSeconds;

  const _LikedTrack({
    required this.trackId,
    required this.title,
    required this.artist,
    this.imageUrl,
    required this.durationSeconds,
  });

  static _LikedTrack? fromRow(Map<String, dynamic> row) {
    // Backend response from listTracksByIdsUser:
    // { track_id, title, duration, album: { title, cover_url }, artists: [{ name, avatar_url }] }
    final trackId = row['track_id']?.toString();
    if (trackId == null || trackId.isEmpty) return null;

    final title = row['title']?.toString() ?? 'Unknown';
    final durationSeconds = (row['duration'] as num?)?.toInt() ?? 0;

    // Artist name from artists array
    String artist = 'Unknown Artist';
    final artists = row['artists'];
    if (artists is List && artists.isNotEmpty) {
      final name = artists.first['name']?.toString();
      if (name != null && name.isNotEmpty) artist = name;
    }

    // Image from album.cover_url
    final album = row['album'];
    final imageUrl = album is Map ? album['cover_url']?.toString() : null;

    return _LikedTrack(
      trackId: trackId,
      title: title,
      artist: artist,
      imageUrl: imageUrl,
      durationSeconds: durationSeconds,
    );
  }
}
