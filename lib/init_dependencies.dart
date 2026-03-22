import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:dio/dio.dart';
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
import 'package:musee/features/admin_users/data/datasources/admin_remote_data_source.dart';
import 'package:musee/features/admin_users/data/repositories/admin_repository_impl.dart';
import 'package:musee/features/admin_users/domain/repository/admin_repository.dart';
import 'package:musee/features/admin_users/domain/usecases/list_users.dart';
import 'package:musee/features/admin_users/domain/usecases/get_user.dart';
import 'package:musee/features/admin_users/domain/usecases/create_user.dart';
import 'package:musee/features/admin_users/domain/usecases/update_user.dart';
import 'package:musee/features/admin_users/domain/usecases/delete_user.dart';
import 'package:musee/features/admin_users/presentation/bloc/admin_users_bloc.dart';
import 'package:musee/features/admin_artists/data/datasources/admin_artists_remote_data_source.dart';
import 'package:musee/features/admin_artists/data/repositories/admin_artists_repository_impl.dart';
import 'package:musee/features/admin_artists/domain/repository/admin_artists_repository.dart';
import 'package:musee/features/admin_artists/domain/usecases/list_artists.dart';
import 'package:musee/features/admin_artists/domain/usecases/get_artist.dart';
import 'package:musee/features/admin_artists/domain/usecases/create_artist.dart';
import 'package:musee/features/admin_artists/domain/usecases/update_artist.dart';
import 'package:musee/features/admin_artists/domain/usecases/delete_artist.dart';
import 'package:musee/features/admin_artists/presentation/bloc/admin_artists_bloc.dart';
import 'package:musee/features/admin_albums/data/datasources/admin_albums_remote_data_source.dart';
import 'package:musee/features/admin_albums/data/repositories/admin_albums_repository_impl.dart';
import 'package:musee/features/admin_albums/domain/repository/admin_albums_repository.dart';
import 'package:musee/features/admin_albums/domain/usecases/list_albums.dart';
import 'package:musee/features/admin_albums/domain/usecases/get_album.dart';
import 'package:musee/features/admin_albums/domain/usecases/create_album.dart';
import 'package:musee/features/admin_albums/domain/usecases/update_album.dart';
import 'package:musee/features/admin_albums/domain/usecases/delete_album.dart';
import 'package:musee/features/admin_albums/domain/usecases/album_artists_ops.dart';
import 'package:musee/features/admin_albums/presentation/bloc/admin_albums_bloc.dart';
import 'package:musee/features/admin_plans/data/datasources/admin_plans_remote_data_source.dart';
import 'package:musee/features/admin_plans/data/repositories/admin_plans_repository_impl.dart';
import 'package:musee/features/admin_plans/domain/repository/admin_plans_repository.dart';
import 'package:musee/features/admin_plans/domain/usecases/list_plans.dart';
import 'package:musee/features/admin_plans/domain/usecases/get_plan.dart';
import 'package:musee/features/admin_plans/domain/usecases/create_plan.dart';
import 'package:musee/features/admin_plans/domain/usecases/update_plan.dart';
import 'package:musee/features/admin_plans/domain/usecases/delete_plan.dart';
import 'package:musee/features/admin_plans/presentation/bloc/admin_plans_bloc.dart';
import 'package:musee/features/admin_tracks/data/datasources/admin_tracks_remote_data_source.dart';
import 'package:musee/features/admin_tracks/data/repositories/admin_tracks_repository_impl.dart';
import 'package:musee/features/admin_tracks/domain/repository/admin_tracks_repository.dart';
import 'package:musee/features/admin_tracks/domain/usecases/list_tracks.dart';
import 'package:musee/features/admin_tracks/domain/usecases/get_track.dart';
import 'package:musee/features/admin_tracks/domain/usecases/create_track.dart';
import 'package:musee/features/admin_tracks/domain/usecases/update_track.dart';
import 'package:musee/features/admin_tracks/domain/usecases/delete_track.dart';
import 'package:musee/features/admin_tracks/domain/usecases/link_track_artist.dart';
import 'package:musee/features/admin_tracks/domain/usecases/update_track_artist_role.dart';
import 'package:musee/features/admin_tracks/domain/usecases/unlink_track_artist.dart';
import 'package:musee/features/admin_tracks/presentation/bloc/admin_tracks_bloc.dart';
import 'package:musee/core/player/player_cubit.dart';
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
import 'package:musee/features/player/data/datasources/player_remote_data_source.dart';
import 'package:musee/features/player/data/repositories/player_repository_impl.dart';
import 'package:musee/features/player/domain/repository/player_repository.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/services/image_cache_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

// New infrastructure services
import 'package:musee/core/providers/providers.dart';
import 'package:musee/core/common/services/connectivity_service.dart';
import 'package:musee/core/download/download_manager.dart';

final serviceLocator = GetIt.instance;

Future<void> initDependencies() async {
  // Initialize Hive for local caching
  await Hive.initFlutter();

  // Initialize external dependencies first
  final supabase = await Supabase.initialize(
    url: AppSecrets.supabaseUrl,
    anonKey: AppSecrets.supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(autoRefreshToken: true),
  );
  serviceLocator.registerLazySingleton(() => supabase.client);
  // Dio for REST backend
  serviceLocator.registerLazySingleton(() => Dio());

  //core
  serviceLocator.registerLazySingleton(() => AppUserCubit());

  // Connectivity service for network monitoring
  serviceLocator.registerLazySingleton<ConnectivityService>(
    () => ConnectivityServiceImpl(),
  );

  // Music provider registry for multi-source music
  serviceLocator.registerLazySingleton<MusicProviderRegistry>(
    () => MusicProviderRegistry([
      MuseeServerProvider(serviceLocator<SupabaseClient>())]),
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

  // Download Manager
  serviceLocator.registerLazySingleton<DownloadManager>(
    () => DownloadManager(
      serviceLocator<AudioCacheService>(),
      serviceLocator<TrackCacheService>(),
      serviceLocator<MusicProviderRegistry>(),
    ),
  );

  // Register player with repository and cache services
  serviceLocator
    ..registerLazySingleton<PlayerDataSource>(
      () => PlayerDataSourceImpl(serviceLocator(), serviceLocator()),
    )
    ..registerLazySingleton<PlayerRepository>(
      () => PlayerRepositoryImpl(serviceLocator()),
    )
    ..registerLazySingleton(
      () => PlayerCubit(
        repository: serviceLocator(),
        trackCache: serviceLocator<TrackCacheService>(),
        audioCache: serviceLocator<AudioCacheService>(),
        imageCache: serviceLocator<ImageCacheService>(),
        musicProviderRegistry: serviceLocator<MusicProviderRegistry>(),
      ),
    );

  //auth
  _initAuth();
  // admin users
  _initAdminUsers();
  // admin artists
  _initAdminArtists();
  // admin albums
  _initAdminAlbums();
  // admin plans
  _initAdminPlans();
  // admin tracks
  _initAdminTracks();
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

void _initAdminUsers() {
  serviceLocator
    // datasource
    ..registerLazySingleton<AdminRemoteDataSource>(
      () => AdminRemoteDataSourceImpl(serviceLocator<Dio>(), serviceLocator()),
    )
    // repository
    ..registerLazySingleton<AdminRepository>(
      () => AdminRepositoryImpl(serviceLocator()),
    )
    // use cases
    ..registerFactory(() => ListUsers(serviceLocator()))
    ..registerFactory(() => GetUser(serviceLocator()))
    ..registerFactory(() => CreateUser(serviceLocator()))
    ..registerFactory(() => UpdateUser(serviceLocator()))
    ..registerFactory(() => DeleteUser(serviceLocator()))
    // bloc
    ..registerFactory(
      () => AdminUsersBloc(
        listUsers: serviceLocator(),
        createUser: serviceLocator(),
        updateUser: serviceLocator(),
        deleteUser: serviceLocator(),
      ),
    );
}

void _initAdminArtists() {
  serviceLocator
    // datasource
    ..registerLazySingleton<AdminArtistsRemoteDataSource>(
      () => AdminArtistsRemoteDataSourceImpl(
        serviceLocator<Dio>(),
        serviceLocator(),
      ),
    )
    // repository
    ..registerLazySingleton<AdminArtistsRepository>(
      () => AdminArtistsRepositoryImpl(serviceLocator()),
    )
    // use cases
    ..registerFactory(() => ListArtists(serviceLocator()))
    ..registerFactory(() => GetArtist(serviceLocator()))
    ..registerFactory(() => CreateArtist(serviceLocator()))
    ..registerFactory(() => UpdateArtist(serviceLocator()))
    ..registerFactory(() => DeleteArtist(serviceLocator()))
    // bloc
    ..registerFactory(
      () => AdminArtistsBloc(
        list: serviceLocator(),
        create: serviceLocator(),
        update: serviceLocator(),
        delete: serviceLocator(),
      ),
    );
}

void _initAdminAlbums() {
  serviceLocator
    // datasource
    ..registerLazySingleton<AdminAlbumsRemoteDataSource>(
      () => AdminAlbumsRemoteDataSourceImpl(
        serviceLocator<Dio>(),
        serviceLocator(),
      ),
    )
    // repository
    ..registerLazySingleton<AdminAlbumsRepository>(
      () => AdminAlbumsRepositoryImpl(serviceLocator()),
    )
    // use cases
    ..registerFactory(() => ListAlbums(serviceLocator()))
    ..registerFactory(() => GetAlbum(serviceLocator()))
    ..registerFactory(() => CreateAlbum(serviceLocator()))
    ..registerFactory(() => UpdateAlbum(serviceLocator()))
    ..registerFactory(() => DeleteAlbum(serviceLocator()))
    ..registerFactory(() => AddAlbumArtist(serviceLocator()))
    ..registerFactory(() => UpdateAlbumArtistRole(serviceLocator()))
    ..registerFactory(() => RemoveAlbumArtist(serviceLocator()))
    // bloc
    ..registerFactory(
      () => AdminAlbumsBloc(
        list: serviceLocator(),
        create: serviceLocator(),
        update: serviceLocator(),
        delete: serviceLocator(),
      ),
    );
}

void _initAdminPlans() {
  serviceLocator
    // datasource
    ..registerLazySingleton<AdminPlansRemoteDataSource>(
      () => AdminPlansRemoteDataSourceImpl(
        serviceLocator<Dio>(),
        serviceLocator(),
      ),
    )
    // repository
    ..registerLazySingleton<AdminPlansRepository>(
      () => AdminPlansRepositoryImpl(serviceLocator()),
    )
    // use cases
    ..registerFactory(() => ListPlans(serviceLocator()))
    ..registerFactory(() => GetPlan(serviceLocator()))
    ..registerFactory(() => CreatePlan(serviceLocator()))
    ..registerFactory(() => UpdatePlan(serviceLocator()))
    ..registerFactory(() => DeletePlan(serviceLocator()))
    // bloc
    ..registerFactory(
      () => AdminPlansBloc(
        list: serviceLocator(),
        create: serviceLocator(),
        update: serviceLocator(),
        delete: serviceLocator(),
      ),
    );
}

void _initAdminTracks() {
  serviceLocator
    // datasource
    ..registerLazySingleton<AdminTracksRemoteDataSource>(
      () => AdminTracksRemoteDataSourceImpl(
        serviceLocator<Dio>(),
        serviceLocator(),
      ),
    )
    // repository
    ..registerLazySingleton<AdminTracksRepository>(
      () => AdminTracksRepositoryImpl(serviceLocator()),
    )
    // use cases
    ..registerFactory(() => ListTracks(serviceLocator()))
    ..registerFactory(() => GetTrack(serviceLocator()))
    ..registerFactory(() => CreateTrack(serviceLocator()))
    ..registerFactory(() => UpdateTrack(serviceLocator()))
    ..registerFactory(() => DeleteTrack(serviceLocator()))
    ..registerFactory(() => LinkTrackArtist(serviceLocator()))
    ..registerFactory(() => UpdateTrackArtistRole(serviceLocator()))
    ..registerFactory(() => UnlinkTrackArtist(serviceLocator()))
    // bloc
    ..registerFactory(
      () => AdminTracksBloc(
        list: serviceLocator(),
        create: serviceLocator(),
        update: serviceLocator(),
        delete: serviceLocator(),
        linkArtist: serviceLocator(),
        updateArtistRole: serviceLocator(),
        unlinkArtist: serviceLocator(),
      ),
    );
}

void _initUserAlbums() {
  serviceLocator
    // datasource
    ..registerLazySingleton<UserAlbumsRemoteDataSource>(
      () => UserAlbumsRemoteDataSourceImpl(
        serviceLocator<Dio>(),
        serviceLocator(),
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
        serviceLocator<Dio>(),
        serviceLocator(),
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
        serviceLocator<Dio>(),
        serviceLocator(),
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
      () => SearchRemoteDataSourceImpl(serviceLocator<SupabaseClient>()),
    )
    // repository
    ..registerLazySingleton<SearchRepository>(
      () => SearchRepositoryImpl(serviceLocator()),
    )
    // use cases
    ..registerFactory(() => GetSuggestions(serviceLocator()))
    ..registerFactory(() => GetSearchResults(serviceLocator()));
}
