import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/core/common/navigation/app_go_router.dart';
import 'package:musee/core/theme/app_colors.dart';
import 'package:musee/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:musee/init_dependencies.dart';
import 'package:path_provider/path_provider.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/core/player/media_controls_service.dart';

// Conditional import for web-specific plugins
import 'web_url_strategy.dart'
    if (dart.library.io) 'web_url_strategy_stub.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //Configure URL strategy for web
  configureUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;

  await MediaControlsService.instance.initialize();

  await initDependencies();

  HydratedBloc.storage = await HydratedStorage.build(
    storageDirectory: kIsWeb
        ? HydratedStorageDirectory.web
        : HydratedStorageDirectory((await getTemporaryDirectory()).path),
  );

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => serviceLocator<AuthBloc>()),
        BlocProvider(create: (_) => serviceLocator<AppUserCubit>()),
        BlocProvider(create: (_) => serviceLocator<PlayerCubit>()),
        BlocProvider(create: (_) => serviceLocator<DownloadManager>()),
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

class _MyAppState extends State<MyApp> {
  late final GoRouter _router;
  bool _hasInitializedAuth = false;

  @override
  void initState() {
    super.initState();
    // Initialize router with AppUserCubit
    _router = AppGoRouter.createRouter(serviceLocator<AppUserCubit>());

    // Add AuthUserLoggedIn event after the first frame to check initial auth state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitializedAuth && mounted) {
        context.read<AuthBloc>().add(AuthUserLoggedIn());
        _hasInitializedAuth = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Musee',
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
      // --- Light Theme Definition ---
      theme: ThemeData(
        cardColor: AppColors.lightColorScheme.secondary.withAlpha(10),
        colorScheme: AppColors.lightColorScheme,
        useMaterial3: true,
      ),
      // Dark Theme
      darkTheme: ThemeData(
        cardColor: AppColors.darkColorScheme.secondary.withAlpha(10),
        colorScheme: AppColors.darkColorScheme,
        useMaterial3: true,
      ),
      // Automatically selects theme based on system settings
      themeMode: ThemeMode.system,
    );
  }
}
