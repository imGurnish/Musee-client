import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/core/common/navigation/app_go_router.dart';
import 'package:musee/core/theme/app_colors.dart';
import 'package:musee/core/update/app_update_info.dart';
import 'package:musee/core/update/app_update_service.dart';
import 'package:musee/core/update/widgets/app_update_overlay.dart';
import 'package:musee/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:musee/init_dependencies.dart';
import 'package:path_provider/path_provider.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:musee/features/settings/presentation/cubit/settings_state.dart';

// Conditional import for web-specific plugins
import 'web_url_strategy.dart'
    if (dart.library.io) 'web_url_strategy_stub.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit for cross-platform playback
  MediaKit.ensureInitialized();

  //Configure URL strategy for web
  configureUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory((await getTemporaryDirectory()).path),
  );

  await initDependencies();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<AuthBloc>()),
        BlocProvider(create: (_) => serviceLocator<AppUserCubit>()),
        BlocProvider(create: (_) => serviceLocator<PlayerCubit>()),
        BlocProvider(create: (_) => serviceLocator<DownloadManager>()),
        BlocProvider(create: (_) => serviceLocator<SettingsCubit>()),
      ],
      // child: DevicePreview(
      //   builder: (BuildContext context) {
      //     return const MyApp();
      //   },
      // ),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final AppUpdateService _updateService;
  bool _hasInitializedAuth = false;
  bool _logoutStopHandled = false;
  AppUpdateInfo? _updateInfo;
  bool _isCheckingUpdate = false;
  bool _dismissedForSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateService = AppUpdateService();
    // Initialize router with AppUserCubit
    _router = AppGoRouter.createRouter(serviceLocator<AppUserCubit>());

    // Add AuthUserLoggedIn event after the first frame to check initial auth state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitializedAuth && mounted) {
        context.read<AuthBloc>().add(AuthUserLoggedIn());
        _hasInitializedAuth = true;
      }

      unawaited(_checkForAppUpdate());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(serviceLocator<PlayerCubit>().stopPlayback());
    }
  }

  Future<void> _checkForAppUpdate() async {
    if (_isCheckingUpdate || _updateInfo != null) {
      return;
    }

    _isCheckingUpdate = true;
    try {
      final updateInfo = await _updateService.checkForUpdate();
      if (!mounted || updateInfo == null) {
        return;
      }

      setState(() {
        _updateInfo = updateInfo;
        _dismissedForSession = false;
      });
    } finally {
      _isCheckingUpdate = false;
    }
  }

  Widget _buildAppFrame(Widget? child) {
    final updateInfo = _updateInfo;
    final shouldShowUpdate = updateInfo != null && !_dismissedForSession;

    return Stack(
      children: [
        if (shouldShowUpdate && updateInfo.isMandatory)
          IgnorePointer(child: child ?? const SizedBox.shrink())
        else
          child ?? const SizedBox.shrink(),
        if (shouldShowUpdate)
          AppUpdateOverlay(
            info: updateInfo,
            onSkip: () {
              if (!mounted) {
                return;
              }

              setState(() {
                _dismissedForSession = true;
              });
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        final isLogoutTransition =
            current is AuthInitial &&
            (previous is AuthLoading || previous is AuthSuccess);

        if (isLogoutTransition && !_logoutStopHandled) {
          return true;
        }

        if (current is AuthSuccess) {
          _logoutStopHandled = false;
        }

        return false;
      },
      listener: (context, state) {
        _logoutStopHandled = true;
        unawaited(
          serviceLocator<PlayerCubit>().stopPlayback(
            clearQueueItems: true,
            clearCurrentTrack: true,
          ),
        );
      },
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settings) {
          final lightScheme = AppColors.getLightScheme(settings.themeProfile);
          final darkScheme = AppColors.getDarkScheme(settings.themeProfile);

          return MaterialApp.router(
            title: 'Musee',
            debugShowCheckedModeBanner: false,
            routerConfig: _router,
            builder: (context, child) => _buildAppFrame(child),
            theme: ThemeData(
              cardColor: lightScheme.secondary.withAlpha(10),
              colorScheme: lightScheme,
              useMaterial3: true,
              scrollbarTheme: ScrollbarThemeData(
                thickness: const WidgetStatePropertyAll(4.0),
                radius: const Radius.circular(8.0),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.dragged)) {
                    return lightScheme.onSurface.withValues(
                      alpha: 0.45,
                    );
                  }
                  return lightScheme.onSurface.withValues(
                    alpha: 0.2,
                  );
                }),
                interactive: true,
              ),
            ),
            // Dark Theme
            darkTheme: ThemeData(
              cardColor: darkScheme.secondary.withAlpha(10),
              colorScheme: darkScheme,
              useMaterial3: true,
              scrollbarTheme: ScrollbarThemeData(
                thickness: const WidgetStatePropertyAll(4.0),
                radius: const Radius.circular(8.0),
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.hovered) ||
                      states.contains(WidgetState.dragged)) {
                    return darkScheme.onSurface.withValues(
                      alpha: 0.45,
                    );
                  }
                  return darkScheme.onSurface.withValues(
                    alpha: 0.2,
                  );
                }),
                interactive: true,
              ),
            ),
            // Driven by SettingsCubit — persists across restarts
            themeMode: settings.themeMode,
          );
        },
      ),
    );
  }
}
