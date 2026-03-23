class Routes {
  // Primary user-facing dashboard
  static const String dashboard = '/dashboard';

  // Admin dashboard
  static const String adminDashboard = '/admin';
  static const String adminUsers = '/admin/users';
  static const String adminUserCreate = '/admin/users/create-new';
  static const String adminUserDetail = '/admin/users/:id';
  static const String adminArtists = '/admin/artists';
  static const String adminArtistCreate = '/admin/artists/create-new';
  static const String adminArtistDetail = '/admin/artists/:id';
  static const String adminAlbums = '/admin/albums';
  static const String adminAlbumCreate = '/admin/albums/create-new';
  static const String adminAlbumDetail = '/admin/albums/:id';
  static const String adminPlans = '/admin/plans';
  static const String adminTracks = '/admin/tracks';
  static const String adminTrackCreate = '/admin/tracks/create-new';
  static const String adminTrackDetail = '/admin/tracks/:id';
  static const String adminTrackImport = '/admin/tracks/import/external';
  static const String adminAlbumImport = '/admin/albums/import/external';
  static const String adminPlaylists = '/admin/playlists';
  static const String adminPlaylistImport = '/admin/playlists/import/external';

  // Authentication
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';

  // User album details
  static const String userAlbum = '/albums/:id';

  // Forbidden / error
  static const String forbidden = '/forbidden';

  // Root (legacy) - redirect to dashboard
  static const String root = '/';
}
