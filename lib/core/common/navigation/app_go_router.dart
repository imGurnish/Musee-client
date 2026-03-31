import 'package:musee/core/common/cubit/app_user_cubit.dart';
import 'package:musee/core/common/entities/user.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:musee/features/admin__dashboard/presentation/pages/admin_dashboard.dart';
import 'package:musee/features/auth/presentation/pages/sign_in_page.dart';
import 'package:musee/features/auth/presentation/pages/sign_up_page.dart';
import 'package:musee/features/user__dashboard/presentation/pages/user_dashboard.dart';
import 'package:musee/features/admin_users/presentation/pages/admin_users_page.dart';
import 'package:musee/features/admin_users/presentation/pages/admin_user_create_page.dart';
import 'package:musee/features/admin_users/presentation/pages/admin_user_detail_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/admin_users/presentation/bloc/admin_users_bloc.dart';
import 'package:musee/features/admin_artists/presentation/pages/admin_artists_page.dart';
import 'package:musee/features/admin_artists/presentation/pages/admin_artist_create_page.dart';
import 'package:musee/features/admin_artists/presentation/pages/admin_artist_detail_page.dart';
import 'package:musee/features/admin_artists/presentation/bloc/admin_artists_bloc.dart';
import 'package:musee/features/admin_albums/presentation/bloc/admin_albums_bloc.dart';
import 'package:musee/features/admin_albums/presentation/pages/admin_albums_page.dart';
import 'package:musee/features/admin_albums/presentation/pages/admin_album_create_page.dart';
import 'package:musee/features/admin_albums/presentation/pages/admin_album_detail_page.dart';
import 'package:musee/features/admin_plans/presentation/pages/admin_plans_page.dart';
import 'package:musee/features/admin_plans/presentation/bloc/admin_plans_bloc.dart';
import 'package:musee/features/admin_tracks/presentation/pages/admin_tracks_page.dart';
import 'package:musee/features/admin_tracks/presentation/pages/admin_track_create_page.dart';
import 'package:musee/features/admin_tracks/presentation/pages/admin_track_detail_page.dart';
import 'package:musee/features/admin_tracks/presentation/bloc/admin_tracks_bloc.dart';
import 'package:musee/features/admin_external_import/presentation/pages/admin_external_import_page.dart';
import 'package:musee/features/admin_playlists/presentation/pages/admin_playlists_page.dart';
import 'package:musee/features/admin_playlists/presentation/pages/admin_playlist_detail_page.dart';
import 'package:musee/features/admin_playlists/presentation/bloc/admin_playlist_detail_bloc.dart';
import 'package:musee/features/admin_countries/presentation/pages/admin_countries_page.dart';
import 'package:musee/features/admin_regions/presentation/pages/admin_regions_page.dart';
import 'package:musee/init_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:musee/features/user_albums/presentation/pages/user_album_page.dart';
import 'package:musee/features/search/presentation/pages/search_page.dart';
import 'package:musee/features/search/presentation/pages/search_results_page.dart';
import 'package:musee/features/search/presentation/bloc/search_bloc.dart';
import 'package:musee/core/common/pages/coming_soon_page.dart';
import 'package:musee/features/user_artists/presentation/pages/user_artist_page.dart';
import 'package:musee/features/user_artists/presentation/bloc/user_artist_bloc.dart';
import 'package:musee/features/library/presentation/pages/user_library_page.dart';
import 'package:musee/features/library/presentation/pages/downloads_page.dart';

class AppGoRouter {
  static GoRouter createRouter(AppUserCubit appUserCubit) {
    final isAdmin =
        appUserCubit.state is AppUserLoggedIn &&
        (appUserCubit.state as AppUserLoggedIn).user.userType == UserType.admin;

    return GoRouter(
      debugLogDiagnostics: true,
      // Start from dashboard; redirect callback will handle admin vs user
      // and unauthenticated cases.
      initialLocation: Routes.dashboard,
      refreshListenable: AppUserChangeNotifier(appUserCubit),
      redirect: (context, state) {
        final appState = appUserCubit.state;
        final isAuthenticated = appState is AppUserLoggedIn;
        final user = isAuthenticated ? (appState).user : null;
        final isAdmin = user?.userType == UserType.admin;

        final intendedLocation = state.uri.toString();
        final isGoingToSignIn = intendedLocation.startsWith(Routes.signIn);
        final isGoingToSignUp = intendedLocation.startsWith(Routes.signUp);

        // If not authenticated, send to sign-in (unless already on auth routes)
        if (!isAuthenticated && !isGoingToSignIn && !isGoingToSignUp) {
          return '${Routes.signIn}?redirect=${Uri.encodeComponent(intendedLocation)}';
        }

        // Authenticated admin user
        if (isAuthenticated && isAdmin) {
          // If hitting root, prefer admin dashboard
          if (intendedLocation == Routes.root) {
            return Routes.adminDashboard;
          }
          return null; // allow navigation
        }

        // Authenticated non-admin user
        if (isAuthenticated && !isAdmin) {
          // Block access to admin routes
          if (intendedLocation.startsWith(Routes.adminDashboard) ||
              intendedLocation.startsWith('/admin')) {
            return Routes.forbidden;
          }

          // If already signed in and trying to go to sign-in, redirect to
          // desired redirect target or normal dashboard.
          if (isGoingToSignIn) {
            final redirectUri =
                state.uri.queryParameters['redirect'] ?? Routes.dashboard;
            return redirectUri;
          }

          return null; // allow navigation
        }

        // Unauthenticated users on /sign-in or /sign-up, or any other fallback
        return null;
      },
      routes: [
        // Legacy root -> redirect to canonical dashboard
        GoRoute(
          path: Routes.root,
          redirect: (context, state) =>
              isAdmin ? Routes.adminArtists : Routes.dashboard,
        ),

        GoRoute(
          path: Routes.dashboard,
          name: 'user_dashboard',
          builder: (context, state) => UserDashboard(),
        ),

        GoRoute(
          path: Routes.adminDashboard,
          name: 'admin_dashboard',
          builder: (context, state) => AdminDashboard(),
        ),

        GoRoute(
          path: Routes.adminUsers,
          name: 'admin_users',
          builder: (context, state) => BlocProvider(
            create: (_) => serviceLocator<AdminUsersBloc>(),
            child: const AdminUsersPage(),
          ),
        ),

        GoRoute(
          path: Routes.adminUserCreate,
          name: 'admin_user_create',
          builder: (context, state) => const AdminUserCreatePage(),
        ),

        GoRoute(
          path: Routes.adminUserDetail,
          name: 'admin_user_detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return AdminUserDetailPage(userId: id);
          },
        ),

        GoRoute(
          path: Routes.adminArtists,
          name: 'admin_artists',
          builder: (context, state) => BlocProvider(
            create: (_) => serviceLocator<AdminArtistsBloc>(),
            child: const AdminArtistsPage(),
          ),
        ),

        GoRoute(
          path: Routes.adminArtistCreate,
          name: 'admin_artist_create',
          builder: (context, state) => BlocProvider(
            create: (_) => serviceLocator<AdminArtistsBloc>(),
            child: const AdminArtistCreatePage(),
          ),
        ),

        GoRoute(
          path: Routes.adminArtistDetail,
          name: 'admin_artist_detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return BlocProvider(
              create: (_) => serviceLocator<AdminArtistsBloc>(),
              child: AdminArtistDetailPage(artistId: id),
            );
          },
        ),

        GoRoute(
          path: Routes.adminAlbums,
          name: 'admin_albums',
          builder: (context, state) => BlocProvider(
            create: (_) => serviceLocator<AdminAlbumsBloc>(),
            child: const AdminAlbumsPage(),
          ),
        ),

        GoRoute(
          path: Routes.adminAlbumCreate,
          name: 'admin_album_create',
          builder: (context, state) => const AdminAlbumCreatePage(),
        ),

        GoRoute(
          path: Routes.adminAlbumDetail,
          name: 'admin_album_detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return AdminAlbumDetailPage(albumId: id);
          },
        ),

        GoRoute(
          path: Routes.adminPlans,
          name: 'admin_plans',
          builder: (context, state) => BlocProvider(
            create: (_) => serviceLocator<AdminPlansBloc>(),
            child: const AdminPlansPage(),
          ),
        ),

        GoRoute(
          path: Routes.adminTracks,
          name: 'admin_tracks',
          builder: (context, state) => BlocProvider(
            create: (_) => serviceLocator<AdminTracksBloc>(),
            child: const AdminTracksPage(),
          ),
        ),

        GoRoute(
          path: Routes.adminTrackCreate,
          name: 'admin_track_create',
          builder: (context, state) => const AdminTrackCreatePage(),
        ),

        GoRoute(
          path: Routes.adminTrackDetail,
          name: 'admin_track_detail',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return AdminTrackDetailPage(trackId: id);
          },
        ),

        GoRoute(
          path: Routes.adminTrackImport,
          name: 'admin_track_import',
          builder: (context, state) => const AdminExternalImportPage(),
        ),

        GoRoute(
          path: Routes.adminAlbumImport,
          name: 'admin_album_import',
          builder: (context, state) => const AdminExternalImportPage(),
        ),

        GoRoute(
          path: Routes.adminImport,
          name: 'admin_import',
          builder: (context, state) => const AdminExternalImportPage(),
        ),

        GoRoute(
          path: Routes.adminPlaylists,
          name: 'admin_playlists',
          builder: (context, state) => const AdminPlaylistsPage(),
        ),

        GoRoute(
          path: '/admin/playlists/:id',
          name: 'admin_playlist_detail',
          builder: (context, state) {
            final playlistId = state.pathParameters['id'] ?? '';
            return BlocProvider(
              create: (context) =>
                  serviceLocator<AdminPlaylistDetailBloc>(),
              child: AdminPlaylistDetailPage(playlistId: playlistId),
            );
          },
        ),

        GoRoute(
          path: Routes.adminCountries,
          name: 'admin_countries',
          builder: (context, state) => const AdminCountriesPage(),
        ),

        GoRoute(
          path: Routes.adminRegions,
          name: 'admin_regions',
          builder: (context, state) => const AdminRegionsPage(),
        ),

        GoRoute(
          path: Routes.adminPlaylistImport,
          name: 'admin_playlist_import',
          builder: (context, state) => const AdminExternalImportPage(),
        ),

        GoRoute(
          path: Routes.signIn,
          name: 'sign-in',
          builder: (context, state) {
            final redirectUrl =
                state.uri.queryParameters['redirect'] ?? Routes.dashboard;
            final newSignUp =
                state.uri.queryParameters['new-sign-up'] == 'true';
            return SignInPage(redirectUrl: redirectUrl, newSignUp: newSignUp);
          },
        ),

        GoRoute(
          path: Routes.signUp,
          name: 'sign-up',
          builder: (context, state) {
            final redirectUrl =
                state.uri.queryParameters['redirect'] ?? Routes.dashboard;
            return SignUpPage(redirectUrl: redirectUrl);
          },
        ),

        GoRoute(
          path: Routes.userAlbum,
          name: 'user_album',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return UserAlbumPage(albumId: id);
          },
        ),

        GoRoute(
          path: '/artists/:id',
          name: 'user_artist',
          builder: (context, state) {
            final id = state.pathParameters['id'] ?? '';
            return BlocProvider(
              create: (_) => serviceLocator<UserArtistBloc>(),
              child: UserArtistPage(artistId: id),
            );
          },
        ),

        // Search entry via GoRouter (used by BottomNavBar)
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) {
            final q = state.uri.queryParameters['q'];
            if (q != null && q.trim().isNotEmpty) {
              return BlocProvider(
                create: (_) => SearchBloc(serviceLocator(), serviceLocator()),
                child: SearchResultsPage(query: q),
              );
            }
            return const SearchPage();
          },
        ),

        // Coming soon placeholders
        GoRoute(
          path: '/library',
          name: 'library',
          builder: (context, state) => const UserLibraryPage(),
          routes: [
            GoRoute(
              path: 'downloads',
              name: 'downloads',
              builder: (context, state) => const DownloadsPage(),
            ),
          ],
        ),
        GoRoute(
          path: '/premium',
          name: 'premium',
          builder: (context, state) =>
              const ComingSoonPage(featureName: 'Premium', selectedIndex: 3),
        ),
        GoRoute(
          path: '/create',
          name: 'create',
          builder: (context, state) =>
              const ComingSoonPage(featureName: 'Create', selectedIndex: 4),
        ),

        GoRoute(
          path: Routes.forbidden,
          name: 'forbidden',
          builder: (context, state) => const ForbiddenPage(),
        ),
      ],
      errorBuilder: (context, state) => const ErrorPage(),
    );
  }
}

// Custom ChangeNotifier to listen to AppUserCubit state changes
class AppUserChangeNotifier extends ChangeNotifier {
  final AppUserCubit _appUserCubit;
  late final StreamSubscription _subscription;

  AppUserChangeNotifier(this._appUserCubit) {
    _subscription = _appUserCubit.stream.listen((_) {
      // Use addPostFrameCallback to prevent setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Check if the notifier is still valid before calling notifyListeners
        if (!_subscription.isPaused) {
          notifyListeners();
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class ErrorPage extends StatelessWidget {
  const ErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              '404 - Page Not Found',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class ForbiddenPage extends StatelessWidget {
  const ForbiddenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block, size: 64, color: Colors.orange),
            const SizedBox(height: 16),
            const Text(
              '403 - Forbidden',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  }
}
