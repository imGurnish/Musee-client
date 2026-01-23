import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';
import 'package:musee/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:musee/features/user__dashboard/presentation/widgets/horizontal_media_section.dart';
import 'package:musee/features/user__dashboard/presentation/widgets/media_card.dart';
import 'package:musee/features/user__dashboard/presentation/widgets/section_header.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/features/user__dashboard/presentation/bloc/user_dashboard_cubit.dart';
import 'package:get_it/get_it.dart';

import 'package:musee/features/user__dashboard/domain/entities/dashboard_album.dart'; // contains DashboardItem
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint("UserDashboard initialized");
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
      );
    } else {
      // Navigate to album
      context.push('/albums/${item.id}');
    }
  }

  IconData _getIcon(DashboardItemType type) {
    switch (type) {
      case DashboardItemType.track:
        return Icons.music_note_rounded;
      case DashboardItemType.album:
        return Icons.album_rounded;
    }
  }

  String _getSubtitle(DashboardItem item) {
    final artistName = item.artists.isNotEmpty
        ? item.artists.first.name
        : 'Unknown';
    if (item.type == DashboardItemType.track) {
      return 'Song • $artistName';
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
          bottomNavigationBar: BottomNavBar(selectedIndex: 0),
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
                            icon: _getIcon(item.type),
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
                            icon: item.type == DashboardItemType.track
                                ? Icons.trending_up
                                : Icons.album_rounded,
                            onTap: () => _handleItemTap(context, item),
                          ),
                        )
                        .toList();

                    return CustomScrollView(
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
                        const SliverToBoxAdapter(child: SizedBox(height: 12)),
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
                                      onTap: () {
                                        showPlayerBottomSheet(
                                          context,
                                          trackId: t.trackId,
                                          title: t.title,
                                          artist: t.artistName,
                                          imageUrl: t.albumCoverUrl,
                                          localImagePath: t.localImagePath,
                                        );
                                      },
                                    ),
                                  )
                                  .toList(),
                              onSeeAll: () {},
                              cardWidth: isCompact ? 140 : 160,
                            ),
                          ),
                        if (state.recentlyPlayed.isNotEmpty)
                          SliverToBoxAdapter(
                            child: SizedBox(height: isCompact ? 4 : 8),
                          ),
                        SliverToBoxAdapter(
                          child: SectionHeader(
                            title: 'Made for you',
                            onSeeAll: () {},
                          ),
                        ),
                        if (state.loadingMadeForYou)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
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
                          _GridSection(items: madeForYouItems),

                        SliverToBoxAdapter(
                          child: SizedBox(height: isCompact ? 4 : 8),
                        ),
                        SliverToBoxAdapter(
                          child: SectionHeader(
                            title: 'Trending now',
                            onSeeAll: () {},
                          ),
                        ),
                        if (state.loadingTrending)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
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
                          _GridSection(items: trendingItems),

                        SliverToBoxAdapter(
                          child: SizedBox(height: isCompact ? 24 : 32),
                        ),
                      ],
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
        IconButton.filledTonal(
          onPressed: () {},
          icon: const Icon(Icons.notifications_none),
          tooltip: 'Notifications',
        ),
        const SizedBox(width: 8),
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
            final isAdmin =
                state is AppUserLoggedIn &&
                state.user.userType == UserType.admin;
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
                if (isAdmin)
                  const PopupMenuItem(
                    value: 'admin',
                    child: Text('Open admin dashboard'),
                  ),
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

class _GridSection extends StatelessWidget {
  final List<MediaItem> items;
  const _GridSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.crossAxisExtent;
          int crossAxisCount;
          if (w < 400) {
            crossAxisCount = 2;
          } else if (w < 700) {
            crossAxisCount = 3;
          } else if (w < 1000) {
            crossAxisCount = 4;
          } else {
            crossAxisCount = 6;
          }
          // Compute a safer childAspectRatio so MediaCard (square art + text)
          // has enough vertical space and doesn't overflow in short grids.
          const double spacing = 12; // matches main/cross spacing
          final double tileWidth =
              (w - (spacing * (crossAxisCount - 1))) / crossAxisCount;
          const double extraTextHeight = 52; // title+subtitle+gaps+padding
          final double computedRatio =
              tileWidth / (tileWidth + extraTextHeight);
          final double aspectRatio = computedRatio.clamp(0.65, 0.85);

          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: spacing,
              crossAxisSpacing: spacing,
              childAspectRatio: aspectRatio,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = items[index];
              return MediaCard(
                title: item.title,
                subtitle: item.subtitle,
                imageUrl: item.imageUrl,
                fallbackIcon: item.icon,
                onTap: item.onTap,
              );
            }, childCount: items.length),
          );
        },
      ),
    );
  }
}
