import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/common/widgets/playing_bars_animation.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/features/user_artists/domain/entities/user_artist.dart';
import 'package:musee/features/user_artists/presentation/bloc/user_artist_bloc.dart';
import 'package:musee/core/common/widgets/bottom_bar_spacing.dart';

class UserArtistPage extends StatefulWidget {
  final String artistId;
  const UserArtistPage({super.key, required this.artistId});

  @override
  State<UserArtistPage> createState() => _UserArtistPageState();
}

class _UserArtistPageState extends State<UserArtistPage> {
  late final UserArtistBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.I<UserArtistBloc>();
    _bloc.add(UserArtistLoadRequested(widget.artistId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserArtistBloc>.value(
      value: _bloc,
      child: _UserArtistView(artistId: widget.artistId),
    );
  }
}

class _UserArtistView extends StatefulWidget {
  final String artistId;
  const _UserArtistView({required this.artistId});

  @override
  State<_UserArtistView> createState() => _UserArtistViewState();
}

class _UserArtistViewState extends State<_UserArtistView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final bloc = context.read<UserArtistBloc>();
    final state = bloc.state;
    if (state.isLoading || state.isLoadingMore || state.hasReachedAllEnd) {
      return;
    }

    final threshold = _scrollController.position.maxScrollExtent - 300;
    if (_scrollController.position.pixels >= threshold) {
      bloc.add(
        UserArtistAlbumsLoadRequested(
          artistId: widget.artistId,
          page: state.albumPage + 1,
          limit: state.albumLimit,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<UserArtistBloc, UserArtistState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const _ArtistLoadingView();
            }

            if (state.error != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load artist',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${state.error}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.read<UserArtistBloc>().add(
                          UserArtistLoadRequested(widget.artistId),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final artist = state.artist;
            if (artist == null) {
              return const Center(child: Text('Artist not found'));
            }

            return RefreshIndicator.adaptive(
              onRefresh: () async {
                context.read<UserArtistBloc>().add(
                  UserArtistLoadRequested(widget.artistId),
                );
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width < 420
                      ? 2
                      : (width < 760 ? 3 : 4);

                  final albums = artist.albums;

                  final albumsSection = albums.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.album_outlined,
                                    size: 32,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'No albums available',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = albums[index];
                                if (item.isSingle) {
                                  // Singles play directly — no album detail page.
                                  return _AlbumCard(
                                    title: item.title,
                                    coverUrl: item.coverUrl,
                                    isSingle: true,
                                    singleTrackId: item.singleTrackId,
                                    onTap: () {
                                      if (item.singleTrackId != null) {
                                        showPlayerBottomSheet(
                                          context,
                                          trackId: item.singleTrackId!,
                                          title: item.title,
                                          artist: artist.name ?? '',
                                          imageUrl: item.coverUrl,
                                          artistId: widget.artistId,
                                          openSheet: false,
                                        );
                                      }
                                    },
                                  );
                                }
                                return _AlbumCard(
                                  title: item.title,
                                  coverUrl: item.coverUrl,
                                  isSingle: false,
                                  albumId: item.albumId,
                                  onTap: () =>
                                      context.push('/albums/${item.albumId}'),
                                );
                              },
                              childCount: albums.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 0.66,
                                ),
                          ),
                        );

                  return CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverAppBar(
                        pinned: true,
                        stretch: true,
                        expandedHeight: 320,
                        backgroundColor: theme.colorScheme.surface,
                        surfaceTintColor: theme.colorScheme.surface,
                        title: Text(
                          artist.name ?? 'Artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          collapseMode: CollapseMode.parallax,
                          stretchModes: const [
                            StretchMode.zoomBackground,
                            StretchMode.fadeTitle,
                          ],
                          background: _ArtistHeader(
                            name: artist.name ?? 'Unknown Artist',
                            coverUrl: artist.coverUrl,
                            avatarUrl: artist.avatarUrl,
                            monthlyListeners: artist.monthlyListeners,
                            genres: artist.genres,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                          child: Row(
                            children: [
                              Text(
                                'Popular',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              if (artist.tracks.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    final first = artist.tracks.first;
                                    showPlayerBottomSheet(
                                      context,
                                      trackId: first.trackId,
                                      title: first.title,
                                      artist:
                                          artist.name ??
                                          first.artists
                                              .map((a) => a.name)
                                              .whereType<String>()
                                              .join(', '),
                                      imageUrl: first.coverUrl,
                                      artistId: widget.artistId,
                                      openSheet: false,
                                    );
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Play'),
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: _PopularTracksSection(
                            tracks: artist.tracks,
                            fallbackArtistName: artist.name,
                          ),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Discography',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      albumsSection,
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                        ),
                      const SliverBottomBarSpacing(mobileHeight: 24),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ArtistHeader extends StatelessWidget {
  final String name;
  final String? coverUrl;
  final String? avatarUrl;
  final int? monthlyListeners;
  final List<String> genres;

  const _ArtistHeader({
    required this.name,
    this.coverUrl,
    this.avatarUrl,
    this.monthlyListeners,
    this.genres = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final textColor = theme.colorScheme.onPrimary;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (coverUrl != null)
          Image.network(
            coverUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) {
              return Container(color: theme.colorScheme.surfaceContainerHigh);
            },
          )
        else
          Container(color: theme.colorScheme.surfaceContainerHigh),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: isNarrow ? 48 : 64,
                backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? NetworkImage(avatarUrl!)
                    : null,
                child: (avatarUrl == null || avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 48)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: isNarrow
                          ? theme.textTheme.headlineSmall?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w900,
                            )
                          : theme.textTheme.displaySmall?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w900,
                            ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (monthlyListeners != null)
                          _HeaderChip(
                            label:
                                '${_formatNumber(monthlyListeners!)} monthly listeners',
                          ),
                        for (final genre in genres.take(2))
                          _HeaderChip(label: genre),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _AlbumCard extends StatelessWidget {
  final String title;
  final String? coverUrl;
  final bool isSingle;
  final String? albumId;
  final String? singleTrackId;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.title,
    this.coverUrl,
    required this.isSingle,
    this.albumId,
    this.singleTrackId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: coverUrl != null && coverUrl!.isNotEmpty
                          ? Image.network(
                              coverUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) {
                                return Center(
                                  child: Icon(
                                    isSingle
                                        ? Icons.music_note_rounded
                                        : Icons.album_rounded,
                                    size: 44,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Icon(
                                isSingle
                                    ? Icons.music_note_rounded
                                    : Icons.album_rounded,
                                size: 44,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                    ),
                  ),
                  // Frosted glass equalizer overlay when active
                  BlocBuilder<PlayerCubit, PlayerViewState>(
                    builder: (context, state) {
                      final isActive = isSingle
                          ? (singleTrackId != null && state.track?.trackId == singleTrackId)
                          : (albumId != null && state.track?.albumId == albumId);
                      if (!isActive) return const SizedBox.shrink();

                      return Center(
                        child: ClipOval(
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: theme.colorScheme.surface.withValues(alpha: 0.4),
                                border: Border.all(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: PlayingBarsAnimation(
                                width: 28,
                                height: 22,
                                isPlaying: state.playing,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Single badge overlay
                  if (isSingle)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.93),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Single',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isSingle)
              Text(
                'Single',
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _HeaderChip extends StatelessWidget {
  final String label;
  const _HeaderChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PopularTracksSection extends StatelessWidget {
  final List<UserArtistTrack> tracks;
  final String? fallbackArtistName;

  const _PopularTracksSection({required this.tracks, this.fallbackArtistName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (tracks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'No popular tracks yet.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final visible = tracks.take(8).toList();
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: List.generate(visible.length, (index) {
          final track = visible[index];
          final names = track.artists
              .map((a) => a.name)
              .whereType<String>()
              .where((s) => s.trim().isNotEmpty)
              .toList();
          final subtitle = names.isNotEmpty
              ? names.join(', ')
              : (fallbackArtistName ?? 'Unknown artist');

          return _PopularTrackRow(
            index: index + 1,
            trackId: track.trackId,
            title: track.title,
            subtitle: subtitle,
            durationSeconds: track.duration,
            playCount: track.playCount,
            likesCount: track.likesCount,
            imageUrl: track.coverUrl,
            onPlay: () {
              showPlayerBottomSheet(
                context,
                trackId: track.trackId,
                title: track.title,
                artist: subtitle,
                imageUrl: track.coverUrl,
                artistId: track.artists.isNotEmpty
                    ? track.artists.first.artistId
                    : null,
                openSheet: false,
              );
            },
          );
        }),
      ),
    );
  }
}

class _PopularTrackRow extends StatelessWidget {
  final int index;
  final String trackId;
  final String title;
  final String subtitle;
  final int? durationSeconds;
  final int? playCount;
  final int? likesCount;
  final String? imageUrl;
  final VoidCallback onPlay;

  const _PopularTrackRow({
    required this.index,
    required this.trackId,
    required this.title,
    required this.subtitle,
    required this.durationSeconds,
    required this.playCount,
    required this.likesCount,
    required this.imageUrl,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onPlay,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: BlocBuilder<PlayerCubit, PlayerViewState>(
                builder: (context, state) {
                  final isActive = state.track?.trackId == trackId;
                  if (isActive) {
                    return PlayingBarsAnimation(
                      width: 22,
                      height: 18,
                      isPlaying: state.playing,
                      color: theme.colorScheme.primary,
                    );
                  }
                  return Text(
                    '$index',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: 46,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _trackFallback(theme),
                      )
                    : _trackFallback(theme),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _durationLabel(durationSeconds),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 8),
            BlocBuilder<PlayerCubit, PlayerViewState>(
              builder: (context, state) {
                final isActive = state.track?.trackId == trackId;
                final isCurrentlyPlaying = isActive && state.playing;
                return IconButton(
                  onPressed: () {
                    if (isActive) {
                      context.read<PlayerCubit>().togglePlayPause();
                    } else {
                      onPlay();
                    }
                  },
                  icon: Icon(
                    isCurrentlyPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: isActive ? theme.colorScheme.primary : null,
                  ),
                  tooltip:
                      '${_compactCount(playCount)} plays • ${_compactCount(likesCount)} likes',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _trackFallback(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        size: 22,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _durationLabel(int? seconds) {
  if (seconds == null || seconds <= 0) return '-:--';
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

String _compactCount(int? value) {
  final n = value ?? 0;
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

class _ArtistLoadingView extends StatelessWidget {
  const _ArtistLoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            'Loading artist...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
