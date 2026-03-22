import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:musee/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:musee/features/auth/domain/repository/auth_repository.dart';
import 'package:musee/features/auth/domain/usecases/current_user.dart';
import 'package:musee/features/auth/domain/usecases/google_sign_in.dart';
import 'package:musee/features/auth/domain/usecases/resend_email_verification.dart';
import 'package:musee/features/auth/domain/usecases/send_password_reset_email.dart';
import 'package:musee/features/auth/domain/usecases/user_sign_in.dart';
import 'package:musee/features/auth/domain/usecases/user_sign_up.dart';
import 'package:musee/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:musee/features/auth/domain/usecases/logout_user_usecase.dart';

import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:musee/features/user_albums/data/datasources/user_albums_remote_data_source.dart';
import 'package:musee/features/user_albums/data/repositories/user_albums_repository_impl.dart';
import 'package:musee/features/user_albums/domain/repository/user_albums_repository.dart';
import 'package:musee/features/user_albums/domain/usecases/get_user_album.dart';
import 'package:musee/features/user_albums/presentation/bloc/user_album_bloc.dart';
import 'package:musee/features/user__dashboard/data/datasources/user_dashboard_remote_data_source.dart';
import 'package:musee/features/user__dashboard/data/repositories/user_dashboard_repository_impl.dart';
import 'package:musee/features/user__dashboard/domain/repository/user_dashboard_repository.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_made_for_you.dart';
import 'package:musee/features/user__dashboard/domain/usecases/list_trending.dart';
import 'package:musee/features/user__dashboard/presentation/bloc/user_dashboard_cubit.dart';
import 'package:musee/features/search/data/datasources/search_remote_data_source.dart';
import 'package:musee/features/search/data/repositories/search_repository_impl.dart';
import 'package:musee/features/search/domain/repository/search_repository.dart';
import 'package:musee/features/search/domain/usecases/get_suggestions.dart';
import 'package:musee/features/search/domain/usecases/get_search_results.dart';
import 'package:musee/features/user_artists/data/datasources/user_artists_remote_data_source.dart';
import 'package:musee/features/user_artists/data/repositories/user_artists_repository_impl.dart';
import 'package:musee/features/user_artists/domain/repository/user_artists_repository.dart';
import 'package:musee/features/user_artists/domain/usecases/get_user_artist.dart';
import 'package:musee/features/user_artists/presentation/bloc/user_artist_bloc.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/services/image_cache_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dio/dio.dart';
import 'package:musee/core/cache/services/queue_persistence_service.dart';

// New infrastructure services
import 'package:musee/core/providers/providers.dart';
import 'package:musee/core/common/services/connectivity_service.dart';
import 'package:musee/core/download/download_manager.dart';

final serviceLocator = GetIt.instance;

Future<void> initDependencies() async {
  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Initialize Supabase (kept for auth)
  final supabase = await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );
  serviceLocator.registerLazySingleton(() => supabase.client);
  // Dio kept for user feature data sources that still need it
  serviceLocator.registerLazySingleton(() => Dio());

  //core
  serviceLocator.registerLazySingleton(() => AppUserCubit());

  // Connectivity service for network monitoring
  serviceLocator.registerLazySingleton<ConnectivityService>(
    () => ConnectivityServiceImpl(),
  );

  // Music provider registry — external (JioSaavn) only
  serviceLocator.registerLazySingleton<MusicProviderRegistry>(
    () => MusicProviderRegistry([ExternalMusicProvider()]),
  );

  // Initialize cache services
  final trackCacheService = TrackCacheServiceImpl();
  await trackCacheService.init();
  serviceLocator.registerLazySingleton<TrackCacheService>(
    () => trackCacheService,
  );

  final audioCacheService = AudioCacheServiceImpl(serviceLocator<Dio>());
  await audioCacheService.init();
  serviceLocator.registerLazySingleton<AudioCacheService>(
    () => audioCacheService,
  );

  // Image cache for album artwork
  final imageCacheService = ImageCacheServiceImpl();
  await imageCacheService.init();
  serviceLocator.registerLazySingleton<ImageCacheService>(
    () => imageCacheService,
  );

  // Queue persistence for saving/restoring queue state
  final queuePersistenceService = QueuePersistenceServiceImpl();
  await queuePersistenceService.init();
  serviceLocator.registerLazySingleton<QueuePersistenceService>(
    () => queuePersistenceService,
  );

  // Download Manager
  serviceLocator.registerLazySingleton<DownloadManager>(
    () => DownloadManager(
      serviceLocator<AudioCacheService>(),
      serviceLocator<TrackCacheService>(),
      serviceLocator<MusicProviderRegistry>(),
    ),
  );

  // Register player with queue persistence
  serviceLocator.registerLazySingleton(
    () => PlayerCubit(
      trackCache: serviceLocator<TrackCacheService>(),
      audioCache: serviceLocator<AudioCacheService>(),
      imageCache: serviceLocator<ImageCacheService>(),
      musicProviderRegistry: serviceLocator<MusicProviderRegistry>(),
      queuePersistence: serviceLocator<QueuePersistenceService>(),
    ),
  );

  //auth
  _initAuth();
  // user features
  _initUserAlbums();
  _initUserArtists();
  _initUserDashboard();
  _initSearch();
}

void _initAuth() {
  serviceLocator
    // Datasource
    ..registerFactory<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(supabaseClient: serviceLocator()),
    )
    // Repository
    ..registerFactory<AuthRepository>(
      () => AuthRepositoryImpl(serviceLocator()),
    )
    //Use cases
    ..registerFactory(() => UserSignUp(serviceLocator()))
    ..registerFactory(() => UserSignIn(serviceLocator()))
    ..registerFactory(() => GoogleSignIn(serviceLocator()))
    ..registerFactory(() => CurrentUser(serviceLocator()))
    ..registerFactory(() => ResendEmailVerification(serviceLocator()))
    ..registerFactory(() => LogoutUserUsecase(serviceLocator()))
    ..registerFactory(() => SendPasswordResetEmail(serviceLocator()))
    // Bloc
    ..registerLazySingleton(
      () => AuthBloc(
        userSignUp: serviceLocator(),
        userSignIn: serviceLocator(),
        currentUser: serviceLocator(),
        appUserCubit: serviceLocator(),
        googleSignIn: serviceLocator(),
        resendEmailVerification: serviceLocator(),
        logoutUserUsecase: serviceLocator(),
        sendPasswordResetEmail: serviceLocator(),
      ),
    );
}

void _initUserAlbums() {
  serviceLocator
    // datasource
    ..registerLazySingleton<UserAlbumsRemoteDataSource>(
      () => UserAlbumsRemoteDataSourceImpl(
        serviceLocator<MusicProviderRegistry>(),
      ),
    )
    // repository
    ..registerLazySingleton<UserAlbumsRepository>(
      () => UserAlbumsRepositoryImpl(
        serviceLocator<UserAlbumsRemoteDataSource>(),
        serviceLocator<MusicProviderRegistry>(),
      ),
    )
    // use cases
    ..registerFactory(
      () => GetUserAlbum(serviceLocator<UserAlbumsRepository>()),
    )
    // bloc
    ..registerFactory(() => UserAlbumBloc(serviceLocator<GetUserAlbum>()));
}

void _initUserArtists() {
  serviceLocator
    // datasource
    ..registerLazySingleton<UserArtistsRemoteDataSource>(
      () => UserArtistsRemoteDataSourceImpl(
        serviceLocator<MusicProviderRegistry>(),
      ),
    )
    // repository
    ..registerLazySingleton<UserArtistsRepository>(
      () => UserArtistsRepositoryImpl(serviceLocator()),
    )
    // use case
    ..registerFactory(() => GetUserArtist(serviceLocator()))
    // bloc
    ..registerFactory(() => UserArtistBloc(serviceLocator<GetUserArtist>()));
}

void _initUserDashboard() {
  serviceLocator
    // datasource
    ..registerLazySingleton<UserDashboardRemoteDataSource>(
      () => UserDashboardRemoteDataSourceImpl(
        serviceLocator<MusicProviderRegistry>(),
      ),
    )
    // repository
    ..registerLazySingleton<UserDashboardRepository>(
      () => UserDashboardRepositoryImpl(
        serviceLocator<UserDashboardRemoteDataSource>(),
      ),
    )
    // use cases
    ..registerFactory(
      () => ListMadeForYou(serviceLocator<UserDashboardRepository>()),
    )
    ..registerFactory(
      () => ListTrending(serviceLocator<UserDashboardRepository>()),
    )
    // cubit
    ..registerFactory(
      () => UserDashboardCubit(
        serviceLocator<ListMadeForYou>(),
        serviceLocator<ListTrending>(),
        trackCache: serviceLocator<TrackCacheService>(),
        musicProviderRegistry: serviceLocator<MusicProviderRegistry>(),
      ),
    );
}

void _initSearch() {
  serviceLocator
    // datasource
    ..registerLazySingleton<SearchRemoteDataSource>(
      () => SearchRemoteDataSourceImpl(),
    )
    // repository
    ..registerLazySingleton<SearchRepository>(
      () => SearchRepositoryImpl(serviceLocator()),
    )
    // use cases
    ..registerFactory(() => GetSuggestions(serviceLocator()))
    ..registerFactory(() => GetSearchResults(serviceLocator()));
}
