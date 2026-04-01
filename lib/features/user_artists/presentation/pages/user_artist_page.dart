import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/features/user_artists/presentation/bloc/user_artist_bloc.dart';

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

class _UserArtistView extends StatelessWidget {
  final String artistId;
  const _UserArtistView({required this.artistId});

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
                          UserArtistLoadRequested(artistId),
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
                  UserArtistLoadRequested(artistId),
                );
              },
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final crossAxisCount = width < 420
                      ? 2
                      : (width < 760 ? 3 : 4);

                  late final Widget albumsSection;
                  if (artist.albums.isEmpty) {
                    albumsSection = SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.album_outlined,
                                size: 44,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No albums available',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    albumsSection = SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final album = artist.albums[index];
                          return _AlbumCard(
                            title: album.title,
                            coverUrl: album.coverUrl,
                            onTap: () =>
                                context.push('/albums/${album.albumId}'),
                          );
                        }, childCount: artist.albums.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.66,
                        ),
                      ),
                    );
                  }

                  return CustomScrollView(
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
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Albums',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      albumsSection,
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
  final VoidCallback onTap;

  const _AlbumCard({required this.title, this.coverUrl, required this.onTap});

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
              child: DecoratedBox(
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
                                Icons.album_rounded,
                                size: 44,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Icon(
                            Icons.album_rounded,
                            size: 44,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
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
