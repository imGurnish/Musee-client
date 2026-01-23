import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';
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
      child: const _UserArtistView(),
    );
  }
}

class _UserArtistView extends StatelessWidget {
  const _UserArtistView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<UserArtistBloc, UserArtistState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(
                child: Text('Failed to load artist: ${state.error}'),
              );
            }
            final a = state.artist!;

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 300,
                  backgroundColor: theme.colorScheme.surface,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _ArtistHeader(
                      name: a.name ?? 'Unknown Artist',
                      coverUrl: a.coverUrl,
                      avatarUrl: a.avatarUrl,
                      monthlyListeners: a.monthlyListeners,
                      genres: a.genres,
                    ),
                  ),
                ),

                // Albums grid
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Text(
                      'Albums',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final alb = a.albums[index];
                      return _AlbumCard(
                        title: alb.title,
                        coverUrl: alb.coverUrl,
                        onTap: () => context.push('/albums/${alb.albumId}'),
                      );
                    }, childCount: a.albums.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 3 / 4,
                        ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 0),
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Cover backdrop
        if (coverUrl != null)
          Image.network(coverUrl!, fit: BoxFit.cover)
        else
          Container(color: theme.colorScheme.surfaceContainerHigh),
        // Gradient overlay
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.5),
              ],
            ),
          ),
        ),
        // Foreground content
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
              const SizedBox(width: 16),
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
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            )
                          : theme.textTheme.displaySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (monthlyListeners != null)
                          Text(
                            '${_formatNumber(monthlyListeners!)} monthly listeners',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        if (genres.isNotEmpty) ...[
                          if (monthlyListeners != null)
                            const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              genres.take(3).join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: coverUrl != null && coverUrl!.isNotEmpty
                  ? Image.network(coverUrl!, fit: BoxFit.cover)
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.album_rounded, size: 48),
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
    );
  }
}
