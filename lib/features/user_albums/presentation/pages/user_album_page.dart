import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/user_albums/presentation/bloc/user_album_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/core/providers/music_provider_registry.dart';

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

class _UserAlbumView extends StatelessWidget {
  const _UserAlbumView();

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Future<String?> fetchPlayableUrl(String trackId) async {
      try {
        return GetIt.I<MusicProviderRegistry>().getStreamUrl(trackId);
      } catch (_) {
        return null;
      }
    }

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
            final primaryArtist = album.artists.isNotEmpty
                ? (album.artists.first.name ?? 'Unknown Artist')
                : 'Unknown Artist';

            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 300,
                  backgroundColor: theme.colorScheme.surface,
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _AlbumHeader(
                      title: album.title,
                      artist: primaryArtist,
                      coverUrl: album.coverUrl,
                      releaseDate: album.releaseDate,
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        FilledButton.icon(
                          onPressed: album.tracks.isEmpty
                              ? null
                              : () async {
                                  final first = album.tracks.first;
                                  final url = await fetchPlayableUrl(
                                    first.trackId,
                                  );
                                  if (url == null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to load stream URL',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  await showPlayerBottomSheet(
                                    context,
                                    audioUrl: url,
                                    title: first.title,
                                    artist: first.artists.isNotEmpty
                                        ? (first.artists.first.name ??
                                              primaryArtist)
                                        : primaryArtist,
                                    album: album.title,
                                    imageUrl: album.coverUrl,
                                    trackId: first.trackId,
                                  );
                                },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play'),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: () {},
                          icon: const Icon(Icons.favorite_border_rounded),
                          tooltip: 'Like',
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.more_horiz_rounded),
                          tooltip: 'More',
                        ),
                      ],
                    ),
                  ),
                ),

                // Track list
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final last = index == album.tracks.length - 1;
                    final t = album.tracks[index];
                    final artists = t.artists.isNotEmpty
                        ? t.artists.map((a) => a.name ?? 'Unknown').join(', ')
                        : primaryArtist;
                    return Column(
                      children: [
                        ListTile(
                          leading: Text(
                            '${index + 1}',
                            style: theme.textTheme.labelLarge,
                          ),
                          title: Text(
                            t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            artists,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _fmtDuration(t.duration),
                                style: theme.textTheme.labelSmall,
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.play_arrow_rounded),
                                tooltip: 'Play',
                                onPressed: () async {
                                  final url = await fetchPlayableUrl(t.trackId);
                                  if (url == null) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to load stream URL',
                                          ),
                                        ),
                                      );
                                    }
                                    return;
                                  }
                                  if (!context.mounted) return;
                                  await showPlayerBottomSheet(
                                    context,
                                    audioUrl: url,
                                    title: t.title,
                                    artist: artists,
                                    album: album.title,
                                    imageUrl: album.coverUrl,
                                    trackId: t.trackId,
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.more_vert_rounded),
                                onPressed: () async {
                                  final action = await showMenu<String>(
                                    context: context,
                                    position: const RelativeRect.fromLTRB(
                                      100,
                                      100,
                                      0,
                                      0,
                                    ),
                                    items: const [
                                      PopupMenuItem(
                                        value: 'queue',
                                        child: Text('Add to queue'),
                                      ),
                                    ],
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
                                    await GetIt.I<PlayerCubit>().addToQueue([
                                      item,
                                    ]);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Added to queue'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          onTap: () async {
                            final url = await fetchPlayableUrl(t.trackId);
                            if (url == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Unable to load stream URL'),
                                  ),
                                );
                              }
                              return;
                            }
                            if (!context.mounted) return;
                            await showPlayerBottomSheet(
                              context,
                              audioUrl: url,
                              title: t.title,
                              artist: artists,
                              album: album.title,
                              imageUrl: album.coverUrl,
                              trackId: t.trackId,
                            );
                          },
                        ),
                        if (!last) const Divider(height: 1),
                      ],
                    );
                  }, childCount: album.tracks.length),
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

class _AlbumHeader extends StatelessWidget {
  final String title;
  final String artist;
  final String? coverUrl;
  final String? releaseDate;
  const _AlbumHeader({
    required this.title,
    required this.artist,
    this.coverUrl,
    this.releaseDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Constrain artwork size so it always fits within the flexible space height
        final artSize = isNarrow ? 120.0 : 220.0;
        final art = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: artSize,
            height: artSize,
            child: coverUrl == null
                ? Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.album_rounded, size: 64),
                  )
                : Ink.image(image: NetworkImage(coverUrl!), fit: BoxFit.cover),
          ),
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              art,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: isNarrow
                          ? theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            )
                          : theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      artist,
                      style: isNarrow
                          ? theme.textTheme.titleMedium
                          : theme.textTheme.titleLarge,
                    ),
                    if (releaseDate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        releaseDate!,
                        style:
                            (isNarrow
                                    ? theme.textTheme.bodySmall
                                    : theme.textTheme.bodyMedium)
                                ?.copyWith(color: theme.hintColor),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
