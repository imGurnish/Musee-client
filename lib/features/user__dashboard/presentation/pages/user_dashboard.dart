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
      return 'Song • $artistName';
    }
    if (item.type == DashboardItemType.playlist) {
      return 'Playlist • $artistName';
    }
    return 'Album • $artistName';
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserDashboardCubit>(
      create: (_) => GetIt.I<UserDashboardCubit>()..load(),
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
                    final madeForYouItems = state.madeForYou
                        .map(
                          (item) => MediaItem(
                            title: item.title,
                            subtitle: _getSubtitle(item),
                            imageUrl: item.coverUrl,
                            localImagePath: item.localImagePath,
                            icon: _getIcon(item.type),
                            mediaTypeLabel: _getTypeLabel(item.type),
                            isCached: item.isCached,
                            onTap: () => _handleItemTap(context, item),
                          ),
                        )
                        .toList();

                    final trendingItems = state.trending
                        .map(
                          (item) => MediaItem(
                            title: item.title,
                            subtitle: _getSubtitle(item),
                            imageUrl: item.coverUrl,
                            localImagePath: item.localImagePath,
                            icon: _getIcon(item.type),
                            mediaTypeLabel: _getTypeLabel(item.type),
                            isCached: item.isCached,
                            onTap: () => _handleItemTap(context, item),
                          ),
                        )
                        .toList();

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
                                onSeeAll: () {},
                                cardWidth: isCompact ? 140 : 160,
                              ),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(
                            child: SectionHeader(
                              title: 'Made for you',
                              onSeeAll: () {},
                            ),
                          ),
                          if (state.loadingMadeForYou)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: _HorizontalSectionSkeleton(
                                  cardWidth: isCompact ? 160 : 190,
                                ),
                              ),
                            )
                          else if (state.errorMadeForYou != null)
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
                                items: madeForYouItems,
                                cardWidth: isCompact ? 160 : 190,
                              ),
                            ),

                          SliverToBoxAdapter(
                            child: SizedBox(height: isCompact ? 10 : 14),
                          ),
                          SliverToBoxAdapter(
                            child: SectionHeader(
                              title: 'Trending now',
                              onSeeAll: () {},
                            ),
                          ),
                          if (state.loadingTrending)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: const _TrendingListSkeleton(),
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
                            _TrendingListSection(items: trendingItems),

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

class _TrendingListSection extends StatelessWidget {
  final List<MediaItem> items;
  const _TrendingListSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TrendingTile(item: item),
        );
      },
    );
  }
}

class _TrendingTile extends StatelessWidget {
  final MediaItem item;
  const _TrendingTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: item.onTap,
      child: Ink(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _TrendingImage(item: item),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              children: [
                Icon(
                  _typeIconFromLabel(item.mediaTypeLabel),
                  size: 18,
                  color: color.onSurface.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 8),
                Icon(
                  item.isCached
                      ? Icons.download_done_rounded
                      : Icons.wifi_rounded,
                  size: 18,
                  color: item.isCached
                      ? Colors.green.shade600
                      : color.onSurface.withValues(alpha: 0.6),
                ),
              ],
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

IconData _typeIconFromLabel(String label) {
  switch (label.toLowerCase()) {
    case 'album':
      return Icons.album_rounded;
    case 'playlist':
      return Icons.queue_music_rounded;
    default:
      return Icons.music_note_rounded;
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

class _TrendingListSkeleton extends StatelessWidget {
  const _TrendingListSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.surfaceContainerHighest.withValues(
      alpha: 0.5,
    );

    return Column(
      children: List.generate(5, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 4 ? 0 : 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: baseColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 10,
                        width: 140,
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
          ),
        );
      }),
    );
  }
}
