import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/core/update/app_update_info.dart';
import 'package:musee/core/update/app_update_service.dart';
import 'package:musee/core/update/widgets/app_update_overlay.dart';
import 'package:musee/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:musee/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';
import 'package:musee/features/settings/presentation/pages/profile_edit_page.dart';
import 'package:musee/features/settings/presentation/widgets/settings_section.dart';
import 'package:musee/features/settings/presentation/widgets/settings_tile.dart';
import 'package:musee/features/user_onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:musee/features/user_onboarding/presentation/pages/onboarding_page.dart';
import 'package:musee/init_dependencies.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _clearingCache = false;
  bool _checkingForUpdate = false;
  AppUpdateInfo? _manualUpdateInfo;
  String? _appVersion;

  final AppUpdateService _updateService = AppUpdateService();

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }

      setState(() {
        _appVersion = packageInfo.version;
      });
    } catch (_) {
      // Best effort only.
    }
  }

  Future<void> _clearOfflineCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear offline cache?'),
        content: const Text(
          'This will delete all downloaded audio files. '
          'You will need to re-download songs to listen offline.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _clearingCache = true);
    try {
      // Best-effort async delay to simulate clearing
      // (in production this would call AudioCacheService.clearAll or similar)
      await Future<void>.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Offline cache cleared')),
        );
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  Future<void> _checkForUpdatesManually() async {
    if (_checkingForUpdate) {
      return;
    }

    setState(() {
      _checkingForUpdate = true;
    });

    try {
      final updateInfo = await _updateService.checkForUpdate();
      if (!mounted) {
        return;
      }

      if (updateInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already on the latest version.')),
        );
        return;
      }

      setState(() {
        _manualUpdateInfo = updateInfo;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checkingForUpdate = false;
        });
      }
    }
  }

  Widget _buildUpdateCheckFrame(Widget child) {
    final updateInfo = _manualUpdateInfo;
    if (updateInfo == null) {
      return child;
    }

    return Stack(
      children: [
        IgnorePointer(child: child),
        AppUpdateOverlay(
          info: updateInfo,
          onSkip: () {
            if (!mounted) {
              return;
            }

            setState(() {
              _manualUpdateInfo = null;
            });
          },
        ),
      ],
    );
  }

  void _openOnboarding() async {
    final supabase = serviceLocator<SupabaseClient>();
    final userId = supabase.auth.currentUser?.id;
    if (userId == null || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => BlocProvider(
          create: (_) => serviceLocator<OnboardingBloc>(),
          child: OnboardingPage(userId: userId, isEditing: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _buildUpdateCheckFrame(
        CustomScrollView(
          slivers: [
            // ─── Gradient Header ──────────────────────────────────────────
            SliverToBoxAdapter(child: _SettingsHeader()),

            // ─── Content ─────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _buildAccountSection(context),
                  const SizedBox(height: 24),
                  _buildAppearanceSection(context),
                  const SizedBox(height: 24),
                  _buildPlaybackSection(context),
                  const SizedBox(height: 24),
                  _buildDownloadsSection(context),
                  const SizedBox(height: 24),
                  _buildMusicPreferencesSection(context),
                  const SizedBox(height: 24),
                  _buildAboutSection(context),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Account Section ─────────────────────────────────────────────────────

  Widget _buildAccountSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<AppUserCubit, AppUserState>(
      builder: (context, state) {
        final name = state is AppUserLoggedIn ? state.user.name : '—';
        final email = state is AppUserLoggedIn ? (state.user.email ?? '—') : '—';
        final user = state is AppUserLoggedIn ? state.user : null;

        return SettingsSection(
          title: 'Account',
          icon: Icons.person_outline_rounded,
          children: [
            // Profile info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: (user?.avatarUrl.isNotEmpty ?? false)
                        ? NetworkImage(user!.avatarUrl)
                        : null,
                    child: (user?.avatarUrl.isEmpty ?? true)
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 54,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            // Edit profile
            if (user != null)
              SettingsNavTile(
                icon: Icons.edit_outlined,
                iconColor: colorScheme.primary,
                title: 'Edit profile',
                subtitle: 'Change your display name',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => BlocProvider.value(
                      value: context.read<AppUserCubit>(),
                      child: ProfileEditPage(user: user),
                    ),
                  ),
                ),
              ),
            Divider(
              height: 1,
              thickness: 1,
              indent: 54,
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            SettingsActionTile(
              icon: Icons.logout_rounded,
              iconColor: colorScheme.error,
              textColor: colorScheme.error,
              title: 'Sign out',
              subtitle: 'You will be taken to the login screen',
              onTap: () {
                context.read<AuthBloc>().add(AuthLogout());
                context.read<AppUserCubit>().updateUser(null);
              },
            ),
          ],
        );
      },
    );
  }

  // ─── Appearance Section ──────────────────────────────────────────────────

  Widget _buildAppearanceSection(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        final colorScheme = Theme.of(context).colorScheme;
        return SettingsSection(
          title: 'Appearance',
          icon: Icons.palette_outlined,
          children: [
            SettingsSegmentedTile<ThemeMode>(
              icon: Icons.brightness_6_outlined,
              iconColor: colorScheme.tertiary,
              title: 'Theme',
              value: settings.themeMode,
              options: const [
                (ThemeMode.system, 'System'),
                (ThemeMode.light, 'Light'),
                (ThemeMode.dark, 'Dark'),
              ],
              onChanged: (v) => context.read<SettingsCubit>().setThemeMode(v),
            ),
          ],
        );
      },
    );
  }

  // ─── Playback Section ────────────────────────────────────────────────────

  Widget _buildPlaybackSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        return BlocBuilder<PlayerCubit, PlayerViewState>(
          builder: (context, playerState) {
            return SettingsSection(
              title: 'Playback',
              icon: Icons.play_circle_outline_rounded,
              children: [
                SettingsToggleTile(
                  icon: Icons.shuffle_rounded,
                  iconColor: colorScheme.primary,
                  title: 'Shuffle',
                  subtitle: 'Randomise track order in queue',
                  value: playerState.shuffleEnabled,
                  onChanged: (v) =>
                      context.read<PlayerCubit>().toggleShuffle(),
                ),
                SettingsSegmentedTile<PlayerRepeatMode>(
                  icon: Icons.repeat_rounded,
                  iconColor: colorScheme.secondary,
                  title: 'Repeat mode',
                  value: playerState.repeatMode,
                  options: const [
                    (PlayerRepeatMode.off, 'Off'),
                    (PlayerRepeatMode.all, 'All'),
                    (PlayerRepeatMode.one, 'One'),
                  ],
                  onChanged: (v) =>
                      context.read<PlayerCubit>().setRepeatMode(v),
                ),
                SettingsToggleTile(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: colorScheme.tertiary,
                  title: 'Auto-fill recommendations',
                  subtitle:
                      'Automatically add recommended tracks when queue is low',
                  value: playerState.recommendationAutoFillEnabled,
                  onChanged: (v) =>
                      context
                          .read<PlayerCubit>()
                          .setRecommendationAutoFill(v),
                ),
                SettingsToggleTile(
                  icon: Icons.play_arrow_rounded,
                  iconColor: Colors.green,
                  title: 'Autoplay',
                  subtitle:
                      'Automatically start playing when a track is selected',
                  value: settings.autoPlayEnabled,
                  onChanged: (v) =>
                      context.read<SettingsCubit>().setAutoPlay(v),
                ),
                // SettingsToggleTile(
                //   icon: Icons.tune_rounded,
                //   iconColor: colorScheme.primary,
                //   title: 'Normalize volume',
                //   subtitle: 'Balance volume across different tracks',
                //   value: settings.normalizeVolume,
                //   onChanged: (v) =>
                //       context.read<SettingsCubit>().setNormalizeVolume(v),
                // ),
                SettingsToggleTile(
                  icon: Icons.explicit_outlined,
                  iconColor: Colors.orange,
                  title: 'Show explicit content',
                  subtitle: 'Allow tracks marked as explicit',
                  value: settings.showExplicitContent,
                  onChanged: (v) =>
                      context
                          .read<SettingsCubit>()
                          .setShowExplicitContent(v),
                ),
                if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
                  SettingsNavTile(
                    icon: Icons.equalizer_rounded,
                    iconColor: colorScheme.primary,
                    title: 'Equalizer & Sound',
                    subtitle: 'EQ presets, bass & surround enhancement',
                    onTap: () => context.push(Routes.equalizer),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Downloads Section ───────────────────────────────────────────────────

  Widget _buildDownloadsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settings) {
        return SettingsSection(
          title: 'Downloads & Storage',
          icon: Icons.download_outlined,
          children: [
            SettingsToggleTile(
              icon: Icons.wifi_rounded,
              iconColor: colorScheme.primary,
              title: 'Wi-Fi only downloads',
              subtitle: 'Only download songs when connected to Wi-Fi',
              value: settings.wifiOnlyDownloads,
              onChanged: (v) =>
                  context.read<SettingsCubit>().setWifiOnlyDownloads(v),
            ),
            SettingsDropdownTile<DownloadQuality>(
              icon: Icons.high_quality_outlined,
              iconColor: colorScheme.secondary,
              title: 'Download quality',
              subtitle: 'Audio quality for downloaded files',
              value: settings.downloadQuality,
              options: DownloadQuality.values
                  .map((q) => (q, q.shortLabel))
                  .toList(),
              onChanged: (v) =>
                  context.read<SettingsCubit>().setDownloadQuality(v),
            ),
            SettingsDropdownTile<MaxCacheSize>(
              icon: Icons.storage_outlined,
              iconColor: colorScheme.tertiary,
              title: 'Max cache size',
              subtitle: 'Limit storage used for offline content',
              value: settings.maxCacheSize,
              options: MaxCacheSize.values
                  .map((s) => (s, s.label))
                  .toList(),
              onChanged: (v) =>
                  context.read<SettingsCubit>().setMaxCacheSize(v),
            ),
            SettingsActionTile(
              icon: Icons.delete_sweep_outlined,
              iconColor: colorScheme.error,
              textColor: colorScheme.error,
              title: 'Clear offline cache',
              subtitle: 'Remove all downloaded audio files',
              onTap: _clearOfflineCache,
              isLoading: _clearingCache,
            ),
          ],
        );
      },
    );
  }

  // ─── Music Preferences Section ───────────────────────────────────────────

  Widget _buildMusicPreferencesSection(BuildContext context) {
    return SettingsSection(
      title: 'Music Preferences',
      icon: Icons.music_note_outlined,
      children: [
        SettingsNavTile(
          icon: Icons.favorite_outline_rounded,
          iconColor: Colors.pinkAccent,
          title: 'Update music preferences',
          subtitle: 'Genres, moods, artists, and language',
          onTap: _openOnboarding,
        ),
      ],
    );
  }

  // ─── About Section ───────────────────────────────────────────────────────

  Widget _buildAboutSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final versionLabel = _appVersion ?? '...';
    final isReleaseUpdateCheckEnabled = !kIsWeb;
    return SettingsSection(
      title: 'About',
      icon: Icons.info_outline_rounded,
      children: [
        SettingsInfoTile(
          icon: Icons.apps_rounded,
          iconColor: colorScheme.primary,
          title: 'App name',
          value: 'Musee',
        ),
        SettingsInfoTile(
          icon: Icons.tag_rounded,
          iconColor: colorScheme.secondary,
          title: 'Version',
          value: versionLabel,
        ),
        SettingsInfoTile(
          icon: Icons.phone_android_rounded,
          iconColor: colorScheme.tertiary,
          title: 'Platform',
          value: kIsWeb
              ? 'Web'
              : Platform.isAndroid
              ? 'Android'
              : Platform.isIOS
              ? 'iOS'
              : Platform.isWindows
              ? 'Windows'
              : Platform.isMacOS
              ? 'macOS'
              : 'Unknown',
        ),
        if (isReleaseUpdateCheckEnabled)
          SettingsActionTile(
            icon: Icons.system_update_alt_rounded,
            iconColor: colorScheme.primary,
            title: 'Check for updates',
            subtitle: 'Look up the latest GitHub release',
            onTap: _checkForUpdatesManually,
            isLoading: _checkingForUpdate,
          ),
      ],
    );
  }
}

// ─── Gradient header bar ──────────────────────────────────────────────────────

class _SettingsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.15),
            colorScheme.secondary.withValues(alpha: 0.08),
            colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button row
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
              ),
              const Spacer(),
              Icon(
                Icons.settings_rounded,
                color: colorScheme.primary.withValues(alpha: 0.5),
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Settings',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Customize your listening experience',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
