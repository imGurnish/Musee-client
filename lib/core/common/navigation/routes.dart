class Routes {
  // Primary user-facing dashboard
  static const String dashboard = '/dashboard';

  // Authentication
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';

  // User album details
  static const String userAlbum = '/albums/:id';

  // Root (legacy) - redirect to dashboard
  static const String root = '/';
}
