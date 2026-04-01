import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'dart:math';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/features/user_playlists/presentation/bloc/user_playlist_bloc.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/core/providers/music_provider_registry.dart';
import 'package:musee/core/download/download_manager.dart';

class UserPlaylistPage extends StatefulWidget {
  final String playlistId;

  const UserPlaylistPage({super.key, required this.playlistId});

  @override
  State<UserPlaylistPage> createState() => _UserPlaylistPageState();
}

class _UserPlaylistPageState extends State<UserPlaylistPage> {
  late final UserPlaylistBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.I<UserPlaylistBloc>();
    _bloc.add(UserPlaylistLoadRequested(widget.playlistId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserPlaylistBloc>.value(
      value: _bloc,
      child: const _UserPlaylistView(),
    );
  }
}

class _UserPlaylistView extends StatelessWidget {
  const _UserPlaylistView();

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _fmtDurationLong(int seconds) {
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$mins min';
    return '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playerCubit = GetIt.I<PlayerCubit>();
    final downloadManager = context.read<DownloadManager>();

    Future<String?> fetchPlayableUrl(String trackId) async {
      try {
        return GetIt.I<MusicProviderRegistry>().getStreamUrl(trackId);
      } catch (_) {
        return null;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<UserPlaylistBloc, UserPlaylistState>(
          builder: (context, state) {
            if (state.isLoading && state.playlist == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null && state.playlist == null) {
              return Center(
                child: Text('Failed to load playlist: ${state.error}'),
              );
            }
            final playlist = state.playlist;
            if (playlist == null) {
              return const Center(
                child: Text('Playlist is not available right now'),
              );
            }
            final creatorName = playlist.artists.isNotEmpty
                ? (playlist.artists.first.name ?? 'Unknown Creator')
                : 'Unknown Creator';
            final trackCount = playlist.tracks.length;
            final totalDuration = playlist.totalDuration;
            final explicitCount = playlist.tracks.where((t) => t.isExplicit).length;
            final canPlayPlaylist = playlist.tracks.isNotEmpty;

            Future<void> playTrack(
              String trackId, {
              required String title,
              required String artist,
            }) async {
              final url = await fetchPlayableUrl(trackId);
              if (url == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unable to load stream URL')),
                  );
                }
                return;
              }
              if (!context.mounted) return;
              await showPlayerBottomSheet(
                context,
                audioUrl: url,
                title: title,
                artist: artist,
                album: playlist.name,
                imageUrl: playlist.coverUrl,
                trackId: trackId,
              );
            }

            void downloadTrack(String trackId) {
              downloadManager.addToQueue(trackId);
            }

            void downloadAllTracks() {
              final trackIds = playlist.tracks
                  .map((track) => track.trackId)
                  .toSet()
                  .toList();
              for (final trackId in trackIds) {
                downloadManager.addToQueue(trackId);
              }
            }

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 410,
                  backgroundColor: theme.colorScheme.surface,
                  title: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _PlaylistHeader(
                      title: playlist.name,
                      creator: creatorName,
                      description: playlist.description,
                      coverUrl: playlist.coverUrl,
                      trackCount: trackCount,
                      totalDuration: _fmtDurationLong(totalDuration),
                      explicitCount: explicitCount,
                      isPublic: playlist.isPublic,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: IconButton.filled(
                                onPressed: canPlayPlaylist
                                    ? () async {
                                        final first = playlist.tracks.first;
                                        final artists = first.artists.isNotEmpty
                                            ? (first.artists.first.name ??
                                                creatorName)
                                            : creatorName;
                                        // Replace queue with all playlist tracks
                                        final queueItems = playlist.tracks
                                            .map((track) {
                                              final trackArtists =
                                                  track.artists.isNotEmpty
                                                      ? track.artists
                                                            .map((a) =>
                                                                a.name ??
                                                                'Unknown Artist')
                                                            .join(', ')
                                                      : creatorName;
                                              return QueueItem(
                                                trackId: track.trackId,
                                                title: track.title,
                                                artist: trackArtists,
                                                album: playlist.name,
                                                imageUrl: playlist.coverUrl,
                                                durationSeconds: track.duration,
                                              );
                                            })
                                            .toList();
                                        await playerCubit.replaceQueue(queueItems);
                                        await playTrack(
                                          first.trackId,
                                          title: first.title,
                                          artist: artists,
                                        );
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 26,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: IconButton.outlined(
                                    onPressed: canPlayPlaylist
                                        ? () async {
                                            final randomTrack = playlist.tracks[
                                                Random().nextInt(trackCount)];
                                            final artists = randomTrack
                                                    .artists.isNotEmpty
                                                ? randomTrack.artists
                                                      .map(
                                                        (a) =>
                                                            a.name ??
                                                            'Unknown Artist',
                                                      )
                                                      .join(', ')
                                                : creatorName;
                                            // Replace queue with all playlist tracks
                                            final queueItems = playlist.tracks
                                                .map((track) {
                                                  final trackArtists =
                                                      track.artists.isNotEmpty
                                                      ? track.artists
                                                            .map(
                                                              (a) =>
                                                                  a.name ??
                                                                  'Unknown Artist',
                                                            )
                                                            .join(', ')
                                                      : creatorName;
                                                  return QueueItem(
                                                    trackId: track.trackId,
                                                    title: track.title,
                                                    artist: trackArtists,
                                                    album: playlist.name,
                                                    imageUrl: playlist.coverUrl,
                                                    durationSeconds:
                                                        track.duration,
                                                  );
                                                })
                                                .toList();
                                            await playerCubit
                                                .replaceQueue(queueItems);
                                            await playTrack(
                                              randomTrack.trackId,
                                              title: randomTrack.title,
                                              artist: artists,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.shuffle_rounded,
                                      size: 19,
                                    ),
                                    tooltip: 'Shuffle',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: IconButton.filledTonal(
                                    onPressed: playlist.tracks.isEmpty
                                        ? null
                                        : () async {
                                            final queueItems = playlist.tracks
                                                .map((track) {
                                                  final artists =
                                                      track.artists.isNotEmpty
                                                      ? track.artists
                                                            .map(
                                                              (a) =>
                                                                  a.name ??
                                                                  'Unknown Artist',
                                                            )
                                                            .join(', ')
                                                      : creatorName;
                                                  return QueueItem(
                                                    trackId: track.trackId,
                                                    title: track.title,
                                                    artist: artists,
                                                    album: playlist.name,
                                                    imageUrl: playlist.coverUrl,
                                                    durationSeconds:
                                                        track.duration,
                                                  );
                                                })
                                                .toList();
                                            await playerCubit
                                                .addToQueue(queueItems);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Added $trackCount tracks to queue',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.queue_music_rounded,
                                      size: 19,
                                    ),
                                    tooltip: 'Queue all',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: IconButton.filled(
                                    onPressed: playlist.tracks.isEmpty
                                        ? null
                                        : () {
                                            downloadAllTracks();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Added $trackCount tracks to downloads',
                                                ),
                                              ),
                                            );
                                          },
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                    ),
                                    icon: const Icon(
                                      Icons.download_for_offline_rounded,
                                      size: 19,
                                    ),
                                    tooltip: 'Download all tracks',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'Tracks',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$trackCount',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _fmtDurationLong(totalDuration),
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = playlist.tracks[index];
                      final artists = t.artists.isNotEmpty
                          ? t.artists
                              .map((a) => a.name ?? 'Unknown')
                              .join(', ')
                          : creatorName;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              // Replace queue with all playlist tracks starting from this one
                              final queueItems = playlist.tracks
                                  .skip(index)
                                  .map((track) {
                                    final trackArtists =
                                        track.artists.isNotEmpty
                                            ? track.artists
                                                  .map((a) =>
                                                      a.name ??
                                                      'Unknown Artist')
                                                  .join(', ')
                                            : creatorName;
                                    return QueueItem(
                                      trackId: track.trackId,
                                      title: track.title,
                                      artist: trackArtists,
                                      album: playlist.name,
                                      imageUrl: playlist.coverUrl,
                                      durationSeconds: track.duration,
                                    );
                                  })
                                  .toList();
                              await playerCubit.replaceQueue(queueItems);
                              await playTrack(
                                t.trackId,
                                title: t.title,
                                artist: artists,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          theme.colorScheme.primaryContainer,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                t.title,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$artists • ${_fmtDuration(t.duration)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              theme.textTheme.bodySmall,
                                        ),
                                        if (playlist.isTrackCached(t.trackId) ||
                                            playlist.isTrackOffline(
                                              t.trackId,
                                            ) ||
                                            t.isExplicit)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (t.isExplicit)
                                                  _TrackStatusChip(
                                                    icon:
                                                        Icons.explicit_rounded,
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onTertiaryContainer,
                                                    backgroundColor: theme
                                                        .colorScheme
                                                        .tertiaryContainer,
                                                  ),
                                                if (playlist.isTrackCached(
                                                  t.trackId,
                                                ))
                                                  const _TrackStatusChip(
                                                    icon: Icons
                                                        .cloud_done_rounded,
                                                  ),
                                                if (playlist.isTrackOffline(
                                                  t.trackId,
                                                ))
                                                  const _TrackStatusChip(
                                                    icon: Icons
                                                        .offline_bolt_rounded,
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                    ),
                                    tooltip: 'Play',
                                    onPressed: () async {
                                      // Replace queue with all playlist tracks starting from this one
                                      final queueItems = playlist.tracks
                                          .skip(index)
                                          .map((track) {
                                            final trackArtists = track.artists
                                                    .isNotEmpty
                                                ? track.artists
                                                      .map((a) =>
                                                          a.name ??
                                                          'Unknown Artist')
                                                      .join(', ')
                                                : creatorName;
                                            return QueueItem(
                                              trackId: track.trackId,
                                              title: track.title,
                                              artist: trackArtists,
                                              album: playlist.name,
                                              imageUrl: playlist.coverUrl,
                                              durationSeconds:
                                                  track.duration,
                                            );
                                          })
                                          .toList();
                                      await playerCubit
                                          .replaceQueue(queueItems);
                                      await playTrack(
                                        t.trackId,
                                        title: t.title,
                                        artist: artists,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_horiz_rounded),
                                    tooltip: 'More',
                                    onPressed: () async {
                                      final action =
                                          await showModalBottomSheet<String>(
                                            context: context,
                                            builder: (context) {
                                              return SafeArea(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons
                                                            .queue_music_rounded,
                                                      ),
                                                      title: const Text(
                                                        'Add to queue',
                                                      ),
                                                      onTap: () =>
                                                          Navigator.pop(
                                                            context,
                                                            'queue',
                                                          ),
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons.download_rounded,
                                                      ),
                                                      title: const Text(
                                                        'Download',
                                                      ),
                                                      onTap: () =>
                                                          Navigator.pop(
                                                            context,
                                                            'download',
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                      if (action == 'queue') {
                                        final item = QueueItem(
                                          trackId: t.trackId,
                                          title: t.title,
                                          artist: artists,
                                          album: playlist.name,
                                          imageUrl: playlist.coverUrl,
                                          durationSeconds: t.duration,
                                        );
                                        await playerCubit
                                            .addToQueue([item]);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Added to queue'),
                                            ),
                                          );
                                        }
                                      } else if (action == 'download') {
                                        downloadTrack(t.trackId);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Added to downloads'),
                                            ),
                                          );
                                        }
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
                    childCount: playlist.tracks.length,
                  ),
                ),
                if (playlist.artists.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Creator',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 86,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: playlist.artists.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final artist = playlist.artists[index];
                                return _ArtistChip(
                                  name: artist.name ?? 'Unknown Creator',
                                  avatarUrl: artist.avatarUrl,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrackStatusChip extends StatelessWidget {
  final IconData icon;
  final Color? foregroundColor;
  final Color? backgroundColor;

  const _TrackStatusChip({
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 13,
        color: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  final String title;
  final String creator;
  final String? description;
  final String? coverUrl;
  final int trackCount;
  final String totalDuration;
  final int explicitCount;
  final bool isPublic;

  const _PlaylistHeader({
    required this.title,
    required this.creator,
    required this.coverUrl,
    required this.trackCount,
    required this.totalDuration,
    required this.explicitCount,
    required this.isPublic,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = isNarrow ? 150.0 : 220.0;
        final art = ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: artSize,
            height: artSize,
            child: coverUrl == null
                ? Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.queue_music_rounded, size: 64),
                  )
                : Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.queue_music_rounded, size: 64),
                    ),
                  ),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl != null)
              Opacity(
                opacity: 0.32,
                child: Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    theme.colorScheme.surface.withValues(alpha: 0.92),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: isNarrow
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          art,
                          const SizedBox(height: 14),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Playlist • $creator',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(label: '$trackCount tracks'),
                              _MetaChip(label: totalDuration),
                              if (explicitCount > 0)
                                _MetaChip(label: '$explicitCount explicit'),
                              if (isPublic)
                                _MetaChip(label: 'Public'),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          art,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Playlist • $creator',
                                  style: theme.textTheme.titleLarge,
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _MetaChip(label: '$trackCount tracks'),
                                    _MetaChip(label: totalDuration),
                                    if (explicitCount > 0)
                                      _MetaChip(
                                        label: '$explicitCount explicit',
                                      ),
                                    if (isPublic) _MetaChip(label: 'Public'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ArtistChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ArtistChip({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person_rounded, size: 18)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
