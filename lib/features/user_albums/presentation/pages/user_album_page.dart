import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'dart:math';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/features/user_albums/presentation/bloc/user_album_bloc.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/features/listening_history/data/repositories/listening_history_repository.dart';

class UserAlbumPage extends StatefulWidget {
  final String albumId;
  const UserAlbumPage({super.key, required this.albumId});

  @override
  State<UserAlbumPage> createState() => _UserAlbumPageState();
}

class _UserAlbumPageState extends State<UserAlbumPage> {
  late final UserAlbumBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.I<UserAlbumBloc>();
    _bloc.add(UserAlbumLoadRequested(widget.albumId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserAlbumBloc>.value(
      value: _bloc,
      child: const _UserAlbumView(),
    );
  }
}

class _UserAlbumView extends StatefulWidget {
  const _UserAlbumView();

  @override
  State<_UserAlbumView> createState() => _UserAlbumViewState();
}

class _UserAlbumViewState extends State<_UserAlbumView>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  late final AnimationController _likeAnimController;
  String? _loadedAlbumId;

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    super.dispose();
  }

  void _loadPreference(String albumId) {
    if (_loadedAlbumId == albumId) return;
    _loadedAlbumId = albumId;
    final repo = GetIt.I<ListeningHistoryRepository>();
    repo.getAlbumPreference(albumId).then((pref) {
      if (mounted && pref == 1 && !_isLiked) {
        setState(() => _isLiked = true);
      }
    });
  }

  void _toggleLike(String albumId) {
    final repo = GetIt.I<ListeningHistoryRepository>();
    setState(() {
      _isLiked = !_isLiked;
    });
    if (_isLiked) {
      _likeAnimController.forward(from: 0);
      repo.likeAlbum(albumId);
    } else {
      repo.clearAlbumPreference(albumId);
    }
  }

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

  String? _releaseYear(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) return null;
    final parts = releaseDate.split('-');
    if (parts.isEmpty || parts.first.isEmpty) return null;
    return parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playerCubit = GetIt.I<PlayerCubit>();
    final downloadManager = context.read<DownloadManager>();


    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<UserAlbumBloc, UserAlbumState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(
                child: Text('Failed to load album: ${state.error}'),
              );
            }
            final album = state.album!;
            _loadPreference(album.albumId);
            final primaryArtist = album.artists.isNotEmpty
                ? (album.artists.first.name ?? 'Unknown Artist')
                : 'Unknown Artist';
            final trackCount = album.tracks.length;
            final totalDuration = album.tracks.fold<int>(
              0,
              (sum, track) => sum + track.duration,
            );
            final explicitCount = album.tracks
                .where((t) => t.isExplicit)
                .length;
            final releaseYear = _releaseYear(album.releaseDate);
            final canPlayAlbum = album.tracks.isNotEmpty;

            Future<void> playTrack(
              String trackId, {
              required String title,
              required String artist,
            }) async {
              if (!context.mounted) return;
              // Don't pre-fetch URL — showPlayerBottomSheet with trackId
              // (and no audioUrl) uses playTrackById which shows metadata
              // instantly while resolving the stream URL in the background.
              await showPlayerBottomSheet(
                context,
                title: title,
                artist: artist,
                album: album.title,
                imageUrl: album.coverUrl,
                trackId: trackId,
                openSheet: false,
              );
            }

            void downloadTrack(String trackId) {
              downloadManager.addToQueue(trackId);
            }

            void downloadAllTracks() {
              final trackIds = album.tracks
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
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _AlbumHeader(
                      title: album.title,
                      artist: primaryArtist,
                      coverUrl: album.coverUrl,
                      releaseDate: album.releaseDate,
                      trackCount: trackCount,
                      totalDuration: _fmtDurationLong(totalDuration),
                      explicitCount: explicitCount,
                      releaseYear: releaseYear,
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
                                onPressed: canPlayAlbum
                                    ? () async {
                                        final first = album.tracks.first;
                                        final artists = first.artists.isNotEmpty
                                            ? (first.artists.first.name ??
                                                  primaryArtist)
                                            : primaryArtist;
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
                            const SizedBox(width: 12),
                            // Like button
                            ScaleTransition(
                              scale: Tween<double>(begin: 1.0, end: 1.3)
                                  .chain(CurveTween(curve: Curves.elasticOut))
                                  .animate(_likeAnimController),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: IconButton(
                                  onPressed: () => _toggleLike(album.albumId),
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                    child: Icon(
                                      _isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      key: ValueKey(_isLiked),
                                      color: _isLiked
                                          ? Colors.redAccent
                                          : theme.colorScheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                  ),
                                  tooltip: _isLiked ? 'Unlike' : 'Like',
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
                                    onPressed: canPlayAlbum
                                        ? () async {
                                            final randomTrack = album.tracks[
                                                Random().nextInt(trackCount)];
                                            final artists =
                                                randomTrack.artists.isNotEmpty
                                                ? randomTrack.artists
                                                      .map(
                                                        (a) =>
                                                            a.name ??
                                                            'Unknown Artist',
                                                      )
                                                      .join(', ')
                                                : primaryArtist;
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
                                    onPressed: album.tracks.isEmpty
                                        ? null
                                        : () async {
                                            final queueItems = album.tracks
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
                                                      : primaryArtist;
                                                  return QueueItem(
                                                    trackId: track.trackId,
                                                    title: track.title,
                                                    artist: artists,
                                                    album: album.title,
                                                    imageUrl: album.coverUrl,
                                                    durationSeconds:
                                                        track.duration,
                                                  );
                                                })
                                                .toList();
                                            await playerCubit
                                                .addToQueue(queueItems);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
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
                                    onPressed: album.tracks.isEmpty
                                        ? null
                                        : () {
                                            downloadAllTracks();
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
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

                // Track list
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final t = album.tracks[index];
                    final artists = t.artists.isNotEmpty
                        ? t.artists.map((a) => a.name ?? 'Unknown').join(', ')
                        : primaryArtist;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () async {
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
                                    color: theme.colorScheme.primaryContainer,
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: theme
                                              .colorScheme
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
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.titleMedium
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
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      if (album.isTrackCached(t.trackId) ||
                                          album.isTrackOffline(t.trackId) ||
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
                                                  icon: Icons.explicit_rounded,
                                                  foregroundColor: theme
                                                      .colorScheme
                                                      .onTertiaryContainer,
                                                  backgroundColor: theme
                                                      .colorScheme
                                                      .tertiaryContainer,
                                                ),
                                              if (album.isTrackCached(
                                                t.trackId,
                                              ))
                                                const _TrackStatusChip(
                                                  icon:
                                                      Icons.cloud_done_rounded,
                                                ),
                                              if (album.isTrackOffline(
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
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  tooltip: 'Play',
                                  onPressed: () async {
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
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  ListTile(
                                                    leading: const Icon(
                                                      Icons.queue_music_rounded,
                                                    ),
                                                    title: const Text(
                                                      'Add to queue',
                                                    ),
                                                    onTap: () => Navigator.pop(
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
                                                    onTap: () => Navigator.pop(
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
                                        album: album.title,
                                        imageUrl: album.coverUrl,
                                        durationSeconds: t.duration,
                                      );
                                      await playerCubit.addToQueue([item]);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text('Added to queue'),
                                          ),
                                        );
                                      }
                                    } else if (action == 'download') {
                                      downloadTrack(t.trackId);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Added to downloads',
                                            ),
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
                  }, childCount: album.tracks.length),
                ),

                if (album.artists.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Artists',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 86,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: album.artists.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final artist = album.artists[index];
                                return _ArtistChip(
                                  name: artist.name ?? 'Unknown Artist',
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

class _AlbumHeader extends StatelessWidget {
  final String title;
  final String artist;
  final String? coverUrl;
  final String? releaseDate;
  final int trackCount;
  final String totalDuration;
  final int explicitCount;
  final String? releaseYear;
  const _AlbumHeader({
    required this.title,
    required this.artist,
    this.coverUrl,
    this.releaseDate,
    required this.trackCount,
    required this.totalDuration,
    required this.explicitCount,
    required this.releaseYear,
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
                    child: const Icon(Icons.album_rounded, size: 64),
                  )
                : Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.album_rounded, size: 64),
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
                            artist,
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
                              if (releaseYear != null)
                                _MetaChip(label: releaseYear!),
                              if (explicitCount > 0)
                                _MetaChip(label: '$explicitCount explicit'),
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
                                Text(artist, style: theme.textTheme.titleLarge),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _MetaChip(label: '$trackCount tracks'),
                                    _MetaChip(label: totalDuration),
                                    if (releaseYear != null)
                                      _MetaChip(label: releaseYear!),
                                    if (explicitCount > 0)
                                      _MetaChip(
                                        label: '$explicitCount explicit',
                                      ),
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
            backgroundImage: avatarUrl != null
                ? NetworkImage(avatarUrl!)
                : null,
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
