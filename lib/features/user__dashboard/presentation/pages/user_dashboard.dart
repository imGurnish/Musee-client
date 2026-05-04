import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:musee/features/user__dashboard/presentation/widgets/horizontal_media_section.dart';
import 'package:musee/features/user__dashboard/presentation/widgets/section_header.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/features/user__dashboard/presentation/bloc/user_dashboard_cubit.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart'; // contains DashboardItem
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/features/user_onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:musee/features/user_onboarding/presentation/pages/onboarding_page.dart';
import 'package:musee/init_dependencies.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  bool _hasCheckedOnboarding = false;
  bool _isShowingOnboarding = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint("UserDashboard initialized");
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowOnboardingIfMissing();
    });
  }

  Future<void> _checkAndShowOnboardingIfMissing() async {
    if (!mounted || _hasCheckedOnboarding || _isShowingOnboarding) {
      return;
    }

    _hasCheckedOnboarding = true;

    final appUserState = context.read<AppUserCubit>().state;
    if (appUserState is! AppUserLoggedIn) {
      return;
    }

    final supabase = serviceLocator<SupabaseClient>();
    final userId = supabase.auth.currentUser?.id ?? appUserState.user.id;

    try {
      final result = await supabase
          .from('user_onboarding_preferences')
          .select('user_id')
          .eq('user_id', userId)
          .maybeSingle();

      final hasPreferences = result != null;
      if (!hasPreferences && mounted) {
        _isShowingOnboarding = true;
        await Navigator.of(context).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => BlocProvider(
              create: (_) => serviceLocator<OnboardingBloc>(),
              child: OnboardingPage(userId: userId),
            ),
          ),
        );
        _isShowingOnboarding = false;
      }
    } catch (_) {
      return;
    }
  }

  void _handleItemTap(BuildContext context, DashboardItem item) {
    if (item.type == DashboardItemType.track) {
      // Play track
      showPlayerBottomSheet(
        context,
        trackId: item.id,
        title: item.title,
        artist: item.artists.map((a) => a.name).join(', '),
        imageUrl: item.coverUrl,
        openSheet: false,
      );
    } else if (item.type == DashboardItemType.album) {
      // Navigate to album
      context.push('/albums/${item.id}');
    } else if (item.type == DashboardItemType.playlist) {
      // Navigate to playlist
      context.push('/playlists/${item.id}');
    }
  }

  IconData _getIcon(DashboardItemType type) {
    switch (type) {
      case DashboardItemType.track:
        return Icons.music_note_rounded;
      case DashboardItemType.album:
        return Icons.album_rounded;
      case DashboardItemType.playlist:
        return Icons.queue_music_rounded;
    }
  }

  String _getTypeLabel(DashboardItemType type) {
    switch (type) {
      case DashboardItemType.track:
        return 'Track';
      case DashboardItemType.album:
        return 'Album';
      case DashboardItemType.playlist:
        return 'Playlist';
    }
  }

  String _getSubtitle(DashboardItem item) {
    final artistName = item.artists.isNotEmpty
        ? item.artists.first.name
        : 'Unknown';
    if (item.type == DashboardItemType.track) {
      final plays = item.playCount != null
          ? ' • ${_formatCompactCount(item.playCount)} plays'
          : '';
      final likes = item.likesCount != null
          ? ' • ${_formatCompactCount(item.likesCount)} likes'
          : '';
      return 'Song • $artistName$plays$likes';
    }
    if (item.type == DashboardItemType.playlist) {
      final likes = item.likesCount != null
          ? ' • ${_formatCompactCount(item.likesCount)} likes'
          : '';
      return 'Playlist • $artistName$likes';
    }
    final tracks = item.totalTracks != null
        ? ' • ${item.totalTracks} tracks'
        : '';
    final likes = item.likesCount != null
        ? ' • ${_formatCompactCount(item.likesCount)} likes'
        : '';
    return 'Album • $artistName$tracks$likes';
  }

  String _formatCompactCount(int? value) {
    if (value == null) return '-';
    if (value >= 1000000) {
      final reduced = value / 1000000;
      return reduced >= 10
          ? '${reduced.toStringAsFixed(0)}M'
          : '${reduced.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final reduced = value / 1000;
      return reduced >= 10
          ? '${reduced.toStringAsFixed(0)}K'
          : '${reduced.toStringAsFixed(1)}K';
    }
    return value.toString();
  }

  List<DashboardItem> _collectUniqueItems(
    UserDashboardState state, {
    DashboardItemType? type,
    int limit = 12,
  }) {
    final source = <DashboardItem>[
      ...state.recommendations,
      ...state.trending,
      ...state.madeForYou,
    ];

    final seen = <String>{};
    final output = <DashboardItem>[];
    for (final item in source) {
      if (type != null && item.type != type) continue;
      final key = switch (item.type) {
        DashboardItemType.track => item.trackId ?? item.id,
        DashboardItemType.album => item.albumId ?? item.id,
        DashboardItemType.playlist => item.playlistId ?? item.id,
      };
      if (seen.add(key)) {
        output.add(item);
      }
      if (output.length >= limit) break;
    }

    return output;
  }

  List<DashboardArtist> _collectTopArtists(
    UserDashboardState state, {
    int limit = 12,
  }) {
    final scoreByArtist = <String, int>{};
    final artistById = <String, DashboardArtist>{};
    final items = [
      ...state.recommendations,
      ...state.trending,
      ...state.madeForYou,
    ];

    for (final item in items) {
      if (item.type == DashboardItemType.playlist) continue;

      for (final artist in item.artists) {
        artistById[artist.artistId] = artist;
        scoreByArtist.update(
          artist.artistId,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final sorted = scoreByArtist.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .take(limit)
        .map((entry) => artistById[entry.key])
        .whereType<DashboardArtist>()
        .toList();
  }

  MediaItem _toMediaItem(BuildContext context, DashboardItem item) {
    return MediaItem(
      title: item.title,
      subtitle: _getSubtitle(item),
      imageUrl: item.coverUrl,
      localImagePath: item.localImagePath,
      icon: _getIcon(item.type),
      mediaTypeLabel: _getTypeLabel(item.type),
      isCached: item.isCached,
      onTap: () => _handleItemTap(context, item),
    );
  }

  void _openSuggestedTracks(BuildContext context, UserDashboardState state) {
    final initialTracks = _collectUniqueItems(
      state,
      type: DashboardItemType.track,
      limit: 24,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<UserDashboardCubit>(),
          child: _SuggestedTracksPage(initialTracks: initialTracks),
        ),
      ),
    );
  }

  void _openAlbumsForYou(BuildContext context, UserDashboardState state) {
    final albums = _collectUniqueItems(
      state,
      type: DashboardItemType.album,
      limit: 24,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<UserDashboardCubit>(),
          child: _SuggestedAlbumsPage(initialAlbums: albums),
        ),
      ),
    );
  }

  void _openTrendingPicks(BuildContext context, UserDashboardState state) {
    final trending = _collectUniqueItems(state, limit: 50);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TrendingPicksPage(
          items: trending,
          onItemTap: _handleItemTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserDashboardCubit>(
      create: (_) => GetIt.I<UserDashboardCubit>()..load(limit: 32),
      child: BlocListener<PlayerCubit, PlayerViewState>(
        listener: (context, playerState) {
          if (playerState.track?.trackId != null) {
            context.read<UserDashboardCubit>().refreshRecentlyPlayed();
          }
        },
        listenWhen: (previous, current) {
          return previous.track?.trackId != current.track?.trackId;
        },
        child: Scaffold(
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final isCompact = width < 700;

                return BlocBuilder<UserDashboardCubit, UserDashboardState>(
                  builder: (context, state) {
                    final suggestedTrackItems = _collectUniqueItems(
                      state,
                      type: DashboardItemType.track,
                      limit: 12,
                    ).map((item) => _toMediaItem(context, item)).toList();

                    final albumItems = _collectUniqueItems(
                      state,
                      type: DashboardItemType.album,
                      limit: 12,
                    ).map((item) => _toMediaItem(context, item)).toList();

                    final playlistItems = _collectUniqueItems(
                      state,
                      type: DashboardItemType.playlist,
                      limit: 8,
                    ).map((item) => _toMediaItem(context, item)).toList();

                    final trendingItems = _collectUniqueItems(
                      state,
                      limit: 10,
                    ).map((item) => _toMediaItem(context, item)).toList();

                    final topArtists = _collectTopArtists(state, limit: 10);
                    return RefreshIndicator(
                      onRefresh: () => context.read<UserDashboardCubit>().load(
                        forceRefresh: true,
                      ),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                              child: _HeaderBar(),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: _HeroBanner(),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          if (state.recentlyPlayed.isNotEmpty)
                            SliverToBoxAdapter(
                              child: HorizontalMediaSection(
                                title: 'Recently played',
                                items: state.recentlyPlayed
                                    .map(
                                      (t) => MediaItem(
                                        title: t.title,
                                        subtitle: t.artistName,
                                        imageUrl: t.albumCoverUrl,
                                        localImagePath: t.localImagePath,
                                        icon: Icons.music_note,
                                        mediaTypeLabel: 'Track',
                                        isCached: true,
                                        onTap: () {
                                          showPlayerBottomSheet(
                                            context,
                                            trackId: t.trackId,
                                            title: t.title,
                                            artist: t.artistName,
                                            imageUrl: t.albumCoverUrl,
                                            localImagePath: t.localImagePath,
                                            openSheet: false,
                                          );
                                        },
                                      ),
                                    )
                                    .toList(),
                                cardWidth: isCompact ? 132 : 148,
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(
                            child: SectionHeader(
                              title: 'Suggested tracks',
                              onSeeAll: () =>
                                  _openSuggestedTracks(context, state),
                            ),
                          ),
                          if (state.loadingMadeForYou &&
                              suggestedTrackItems.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: _HorizontalSectionSkeleton(
                                  cardWidth: isCompact ? 132 : 148,
                                ),
                              ),
                            )
                          else if (state.errorMadeForYou != null &&
                              suggestedTrackItems.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Failed to load: ${state.errorMadeForYou}',
                                ),
                              ),
                            )
                          else
                            SliverToBoxAdapter(
                              child: HorizontalMediaSection(
                                title: '',
                                items: suggestedTrackItems,
                                cardWidth: isCompact ? 132 : 148,
                              ),
                            ),

                          SliverToBoxAdapter(
                            child: SizedBox(height: isCompact ? 10 : 14),
                          ),
                          SliverToBoxAdapter(
                            child: SectionHeader(
                              title: 'Trending picks',
                              onSeeAll: () =>
                                  _openTrendingPicks(context, state),
                            ),
                          ),
                          if (state.loadingTrending)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: const _CompactFeedSkeleton(),
                              ),
                            )
                          else if (state.errorTrending != null)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Failed to load: ${state.errorTrending}',
                                ),
                              ),
                            )
                          else
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _CompactFeedSection(
                                  items: trendingItems,
                                ),
                              ),
                            ),

                          SliverToBoxAdapter(
                            child: SizedBox(height: isCompact ? 10 : 14),
                          ),
                          SliverToBoxAdapter(
                            child: SectionHeader(
                              title: 'Albums for you',
                              onSeeAll: () =>
                                  _openAlbumsForYou(context, state),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: HorizontalMediaSection(
                              title: '',
                              items: albumItems,
                              cardWidth: isCompact ? 128 : 142,
                            ),
                          ),

                          if (playlistItems.isNotEmpty)
                            SliverToBoxAdapter(
                              child: SizedBox(height: isCompact ? 10 : 14),
                            ),
                          if (playlistItems.isNotEmpty)
                            SliverToBoxAdapter(
                              child: const SectionHeader(
                                title: 'Playlists to try',
                              ),
                            ),
                          if (playlistItems.isNotEmpty)
                            SliverToBoxAdapter(
                              child: HorizontalMediaSection(
                                title: '',
                                items: playlistItems,
                                cardWidth: isCompact ? 128 : 142,
                              ),
                            ),

                          if (topArtists.isNotEmpty)
                            SliverToBoxAdapter(
                              child: const SectionHeader(
                                title: 'Artists to explore',
                              ),
                            ),
                          if (topArtists.isNotEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: _ArtistPillsSection(artists: topArtists),
                              ),
                            ),

                          SliverToBoxAdapter(
                            child: SizedBox(height: isCompact ? 24 : 32),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BlocBuilder<AppUserCubit, AppUserState>(
                builder: (context, state) {
                  final name = state is AppUserLoggedIn
                      ? state.user.name
                      : 'There';
                  return Text(
                    'Good day, $name',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Text(
                'Let\'s discover some music for you',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withValues(
                    alpha: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        // IconButton.filledTonal(
        //   onPressed: () {},
        //   icon: const Icon(Icons.notifications_none),
        //   tooltip: 'Notifications',
        // ),
        // const SizedBox(width: 8),
        // Quick access to Admin Home if the current user is an admin
        BlocBuilder<AppUserCubit, AppUserState>(
          builder: (context, state) {
            final isAdmin =
                state is AppUserLoggedIn &&
                state.user.userType == UserType.admin;
            if (!isAdmin) return const SizedBox.shrink();
            return IconButton.filledTonal(
              tooltip: 'Admin home',
              onPressed: () => context.push(Routes.adminDashboard),
              icon: const Icon(Icons.admin_panel_settings),
            );
          },
        ),
        const SizedBox(width: 8),
        BlocBuilder<AppUserCubit, AppUserState>(
          builder: (context, state) {
            return PopupMenuButton<String>(
              icon: const CircleAvatar(child: Icon(Icons.person)),
              onSelected: (value) {
                switch (value) {
                  case 'admin':
                    context.push(Routes.adminDashboard);
                    break;
                  case 'logout':
                    context.read<AuthBloc>().add(AuthLogout());
                    context.read<AppUserCubit>().updateUser(null);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'profile', child: Text('Profile')),
                const PopupMenuItem(value: 'settings', child: Text('Settings')),
                const PopupMenuItem(value: 'logout', child: Text('Logout')),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gradient = LinearGradient(
      colors: [
        theme.colorScheme.primary.withValues(alpha: 0.18),
        theme.colorScheme.secondary.withValues(alpha: 0.12),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Here\'s your daily mix and top picks based on your recent listening.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: const [
                    _QuickChip(label: 'Focus'),
                    _QuickChip(label: 'Chill'),
                    _QuickChip(label: 'Workout'),
                    _QuickChip(label: 'Party'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            height: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.graphic_eq, size: 48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  const _QuickChip({required this.label});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      label: Text(label),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}

class _CompactFeedSection extends StatelessWidget {
  final List<MediaItem> items;
  const _CompactFeedSection({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 88,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) => _CompactFeedTile(item: items[index]),
    );
  }
}

class _CompactFeedTile extends StatelessWidget {
  final MediaItem item;
  const _CompactFeedTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: item.onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _TrendingImage(item: item),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingImage extends StatelessWidget {
  final MediaItem item;
  const _TrendingImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    if (item.localImagePath != null) {
      return Image.file(
        File(item.localImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(color),
      );
    }
    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
      return Image.network(item.imageUrl!, fit: BoxFit.cover);
    }
    return _fallback(color);
  }

  Widget _fallback(ColorScheme color) {
    return Container(
      color: color.primaryContainer.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Icon(item.icon, size: 26, color: color.onPrimaryContainer),
    );
  }
}

class _HorizontalSectionSkeleton extends StatelessWidget {
  final double cardWidth;

  const _HorizontalSectionSkeleton({required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );

    return SizedBox(
      height: cardWidth + 110,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, _) => Container(
          width: cardWidth,
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: cardWidth * 0.6,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactFeedSkeleton extends StatelessWidget {
  const _CompactFeedSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 420,
        mainAxisExtent: 88,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 10,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 9,
                      width: 120,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
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

class _ArtistPillsSection extends StatelessWidget {
  final List<DashboardArtist> artists;
  const _ArtistPillsSection({required this.artists});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: artists
          .map(
            (artist) => ActionChip(
              avatar: const Icon(Icons.person, size: 16),
              label: Text(artist.name),
              onPressed: () => context.push('/artists/${artist.artistId}'),
            ),
          )
          .toList(),
    );
  }
}

class _SuggestedTracksPage extends StatefulWidget {
  final List<DashboardItem> initialTracks;
  const _SuggestedTracksPage({required this.initialTracks});

  @override
  State<_SuggestedTracksPage> createState() => _SuggestedTracksPageState();
}

class _SuggestedTracksPageState extends State<_SuggestedTracksPage> {
  late List<DashboardItem> _tracks;
  final _seen = <String>{};
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _reachedEnd = false;
  int _page = 0;
  static const _pageSize = 30;
  static const _maxItems = 200;

  @override
  void initState() {
    super.initState();
    _tracks = [];
    _addUnique(widget.initialTracks);
    _scrollController.addListener(_onScroll);
    _fetchMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addUnique(List<DashboardItem> items) {
    for (final item in items) {
      final key = item.trackId ?? item.id;
      if (_seen.add(key)) _tracks.add(item);
    }
  }

  void _onScroll() {
    if (_loading || _reachedEnd) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchMore();
    }
  }

  Future<void> _fetchMore() async {
    if (_loading || _reachedEnd || _tracks.length >= _maxItems) return;
    setState(() => _loading = true);

    final before = _tracks.length;
    final more = await context.read<UserDashboardCubit>().fetchSuggestedTracks(
      page: _page,
      limit: _pageSize,
    );
    _page++;

    _addUnique(more);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _reachedEnd =
          _tracks.length == before || _tracks.length >= _maxItems;
    });
  }

  void _playTrack(DashboardItem item) {
    showPlayerBottomSheet(
      context,
      trackId: item.trackId ?? item.id,
      title: item.title,
      artist: item.artists.map((artist) => artist.name).join(', '),
      imageUrl: item.coverUrl,
      localImagePath: item.localImagePath,
      openSheet: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suggested tracks (${_tracks.length})'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _tracks.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              controller: _scrollController,
              itemCount: _tracks.length + (_reachedEnd ? 0 : 1),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                if (index >= _tracks.length) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final item = _tracks[index];
                final subtitle = item.artists.isNotEmpty
                    ? item.artists.map((artist) => artist.name).join(', ')
                    : 'Unknown artist';
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: _TrendingImage(
                        item: MediaItem(
                          title: item.title,
                          subtitle: subtitle,
                          imageUrl: item.coverUrl,
                          localImagePath: item.localImagePath,
                          icon: Icons.music_note_rounded,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    onPressed: () => _playTrack(item),
                    icon: const Icon(Icons.play_arrow_rounded),
                  ),
                  onTap: () => _playTrack(item),
                );
              },
            ),
    );
  }
}

class _SuggestedAlbumsPage extends StatefulWidget {
  final List<DashboardItem> initialAlbums;
  const _SuggestedAlbumsPage({required this.initialAlbums});

  @override
  State<_SuggestedAlbumsPage> createState() => _SuggestedAlbumsPageState();
}

class _SuggestedAlbumsPageState extends State<_SuggestedAlbumsPage> {
  late List<DashboardItem> _albums;
  final _seen = <String>{};
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _reachedEnd = false;
  int _page = 0;
  static const _pageSize = 30;
  static const _maxItems = 200;

  @override
  void initState() {
    super.initState();
    _albums = [];
    _addUnique(widget.initialAlbums);
    _scrollController.addListener(_onScroll);
    _fetchMore();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _addUnique(List<DashboardItem> items) {
    for (final item in items) {
      final key = item.albumId ?? item.id;
      if (_seen.add(key)) _albums.add(item);
    }
  }

  void _onScroll() {
    if (_loading || _reachedEnd) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchMore();
    }
  }

  Future<void> _fetchMore() async {
    if (_loading || _reachedEnd || _albums.length >= _maxItems) return;
    setState(() => _loading = true);

    final before = _albums.length;
    final more = await context.read<UserDashboardCubit>().fetchSuggestedAlbums(
      page: _page,
      limit: _pageSize,
    );
    _page++;

    _addUnique(more);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _reachedEnd =
          _albums.length == before || _albums.length >= _maxItems;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Albums for you (${_albums.length})'),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _albums.isEmpty && _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final item = _albums[index];
                        final artistNames = item.artists.isNotEmpty
                            ? item.artists.map((a) => a.name).join(', ')
                            : 'Unknown artist';
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context
                              .push('/albums/${item.albumId ?? item.id}'),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: SizedBox.expand(
                                    child: _AlbumGridImage(item: item),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                artistNames,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                      childCount: _albums.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                  ),
                ),
                if (!_reachedEnd)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _AlbumGridImage extends StatelessWidget {
  final DashboardItem item;
  const _AlbumGridImage({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    if (item.localImagePath != null) {
      return Image.file(
        File(item.localImagePath!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(color),
      );
    }
    if (item.coverUrl != null && item.coverUrl!.isNotEmpty) {
      return Image.network(item.coverUrl!, fit: BoxFit.cover);
    }
    return _fallback(color);
  }

  Widget _fallback(ColorScheme color) {
    return Container(
      color: color.primaryContainer.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child:
          Icon(Icons.album_rounded, size: 48, color: color.onPrimaryContainer),
    );
  }
}

class _TrendingPicksPage extends StatelessWidget {
  final List<DashboardItem> items;
  final void Function(BuildContext, DashboardItem) onItemTap;
  const _TrendingPicksPage({required this.items, required this.onItemTap});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trending picks')),
      body: items.isEmpty
          ? const Center(child: Text('No trending items'))
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                final subtitle = item.artists.isNotEmpty
                    ? item.artists.map((a) => a.name).join(', ')
                    : 'Unknown artist';
                final typeLabel = switch (item.type) {
                  DashboardItemType.track => 'Song',
                  DashboardItemType.album => 'Album',
                  DashboardItemType.playlist => 'Playlist',
                };
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: _TrendingImage(
                        item: MediaItem(
                          title: item.title,
                          subtitle: subtitle,
                          imageUrl: item.coverUrl,
                          localImagePath: item.localImagePath,
                          icon: switch (item.type) {
                            DashboardItemType.track =>
                              Icons.music_note_rounded,
                            DashboardItemType.album => Icons.album_rounded,
                            DashboardItemType.playlist =>
                              Icons.queue_music_rounded,
                          },
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$typeLabel • $subtitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onItemTap(context, item),
                );
              },
            ),
    );
  }
}

