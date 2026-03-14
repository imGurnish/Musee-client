import 'dart:async';
import 'dart:io';

import 'package:musee/core/error/exceptions.dart';
import 'package:musee/features/auth/data/models/user_model.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Contract for authentication data source operations
abstract interface class AuthRemoteDataSource {
  /// Current user session
  Session? get currentSession;

  /// Sign up with email and password
  Future<UserModel> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
  });

  /// Sign in with email and password
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  });

  /// Sign in with Google OAuth
  Future<UserModel> signInWithGoogle();

  // /// Build a UserModel from the Supabase auth user/session (no DB lookup).
  // /// Returns null if there is no authenticated user.
  // Future<UserModel?> getAuthUserModel();

  /// Get current user data
  Future<UserModel?> getCurrentUserData();

  /// Sign out current user
  Future<void> logout();

  /// Resend email verification
  Future<void> resendEmailVerification({required String email});

  // Forget Password
  Future<void> sendPasswordResetEmail({required String email});
}

/// Implementation of authentication data source using Supabase
class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final SupabaseClient supabaseClient;

  // OAuth client IDs
  static const _webClientId =
      '880647919951-kh22q3pdjlp10l61p5g0q8jp6d6gqv3p.apps.googleusercontent.com';
  static const _iosClientId =
      '880647919951-9nukq1e0018m9llr6eu7lh9e6a1frfsq.apps.googleusercontent.com';
  static const _redirectUrl = 'http://localhost:54321/auth/callback';
  static final _emailRedirectUrl = '${Uri.base}/sign-in?new-sign-up=true';

  static final _passwordResetRedirectUrl = '${Uri.base}';

  AuthRemoteDataSourceImpl({required this.supabaseClient});

  @override
  Session? get currentSession => supabaseClient.auth.currentSession;

  @override
  Future<UserModel> signUpWithEmailPassword({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabaseClient.auth.signUp(
        password: password,
        email: email,
        data: {'name': name},
        emailRedirectTo: _emailRedirectUrl,
      );

      if (response.user == null) {
        throw ServerException('User creation failed');
      }

      // Check if email verification is required
      if (response.user!.emailConfirmedAt == null) {
        throw EmailVerificationRequiredException(email);
      }

      return await _getUserData(response.user!.id);
    } on EmailVerificationRequiredException {
      rethrow;
    } catch (e) {
      throw ServerException('Sign up failed: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw const ServerException('Sign in failed');
      }

      return await _getUserData(response.user!.id);
    } catch (e) {
      throw ServerException('Sign in failed: ${e.toString()}');
    }
  }

  @override
  Future<UserModel> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _handleWebGoogleSignIn();
      } else if (Platform.isLinux || Platform.isWindows) {
        return await _handleDesktopGoogleSignIn();
      } else {
        return await _handleMobileGoogleSignIn();
      }
    } catch (e) {
      throw ServerException('Google Sign-In failed: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getCurrentUserData() async {
    try {
      final session = currentSession;
      if (session == null) return null;

      return await _getUserData(session.user.id);
    } catch (e) {
      throw ServerException('Failed to get user data: ${e.toString()}');
    }
  }

  // @override
  // Future<UserModel?> getAuthUserModel() async {
  //   try {
  //     final authUser = supabaseClient.auth.currentUser;
  //     if (authUser == null) return null;

  //     final defaultAvatar =
  //         'https://xvpputhovrhgowfkjhfv.supabase.co/storage/v1/object/public/avatars/users/default_avatar.png';

  //     final nameFromMetadata = authUser.userMetadata?['name'] as String?;
  //     final avatarFromMetadata =
  //         authUser.userMetadata?['avatar_url'] as String?;

  //     return UserModel(
  //       id: authUser.id,
  //       name: nameFromMetadata ?? authUser.email ?? 'User',
  //       email: authUser.email,
  //       avatarUrl: avatarFromMetadata ?? defaultAvatar,
  //     );
  //   } catch (e) {
  //     // Don't throw; return null to indicate no auth user could be built.
  //     return null;
  //   }
  // }

  @override
  Future<void> logout() async {
    try {
      await supabaseClient.auth.signOut();
    } catch (e) {
      throw ServerException('Logout failed: ${e.toString()}');
    }
  }

  @override
  Future<void> resendEmailVerification({required String email}) async {
    try {
      await supabaseClient.auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      throw ServerException('Failed to resend verification: ${e.toString()}');
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      if (kDebugMode) print("Sending password reset email to $email");
      await supabaseClient.auth.resetPasswordForEmail(
        email,
        redirectTo: _passwordResetRedirectUrl,
      );
    } catch (e) {
      throw ServerException(
        'Failed to send password reset email: ${e.toString()}',
      );
    }
  }

  // Private helper methods

  /// Handle Google Sign-In for web platform
  Future<UserModel> _handleWebGoogleSignIn() async {
    await supabaseClient.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: '${Uri.base.origin}/sign-in?redirect=/',
    );

    throw 'OAuth flow initiated - awaiting redirect';
  }

  /// Handle Google Sign-In for desktop platforms
  Future<UserModel> _handleDesktopGoogleSignIn() async {
    final completer = Completer<Session>();

    final server = await io.serve(
      _createAuthCallbackHandler(completer),
      InternetAddress.loopbackIPv4,
      54321,
    );

    try {
      await supabaseClient.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _redirectUrl,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );

      final session = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException('Login timed out'),
      );

      return await _getUserData(session.user.id);
    } finally {
      await server.close(force: true);
    }
  }

  /// Handle Google Sign-In for mobile platforms
  Future<UserModel> _handleMobileGoogleSignIn() async {
    try {
      final googleSignIn = GoogleSignIn(
        // On iOS/macOS provide the iOS clientId; on Android keep it null.
        clientId: (Platform.isIOS || Platform.isMacOS) ? _iosClientId : null,
        serverClientId: _webClientId,
        scopes: ['email', 'profile', 'openid'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled sign-in; wrap in ServerException so UI can show a clear message.
        throw ServerException('User cancelled Google Sign-In');
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        throw ServerException('No ID Token received from Google');
      }

      final response = await supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user == null) {
        throw ServerException('Failed to authenticate with Supabase');
      }

      return await _getUserData(response.user!.id);
    } on ServerException {
      rethrow;
    } catch (e) {
      // Unexpected errors: wrap so repository can surface a useful message.
      throw ServerException('Google Sign-In failed: $e');
    }
  }

  /// Create HTTP handler for OAuth callback
  Handler _createAuthCallbackHandler(Completer<Session> completer) {
    return (Request req) async {
      final uri = req.requestedUri;

      if (uri.path != '/auth/callback') {
        return Response.notFound('Not Found');
      }

      final code = uri.queryParameters['code'];
      if (code == null) {
        return Response.badRequest(
          body: _buildErrorPage(
            'Missing authorization code. Please try again.',
          ),
          headers: {'content-type': 'text/html'},
        );
      }

      try {
        final response = await supabaseClient.auth.exchangeCodeForSession(code);
        final session = response.session;

        if (!completer.isCompleted) {
          completer.complete(session);
        }

        return Response.ok(
          _buildSuccessPage(),
          headers: {'content-type': 'text/html'},
        );
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        return Response.internalServerError(
          body: _buildErrorPage('Authentication failed. Please try again.'),
          headers: {'content-type': 'text/html'},
        );
      }
    };
  }

  Future<UserModel> _getUserData(String id) async {
    if (kDebugMode) {
      debugPrint('Fetching user data for ID: $id');
    }

    try {
      // Try to get user profile from Supabase 'users' table
      final response = await supabaseClient
          .from('users')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response != null) {
        if (kDebugMode) debugPrint('✅ User data from Supabase: $response');
        return UserModel.fromJson(response);
      }

      // Fallback: build UserModel from Supabase auth metadata
      final authUser = supabaseClient.auth.currentUser;
      if (authUser != null) {
        final defaultAvatar =
            'https://xvpputhovrhgowfkjhfv.supabase.co/storage/v1/object/public/avatars/users/default_avatar.png';

        final nameFromMetadata = authUser.userMetadata?['name'] as String?;
        final avatarFromMetadata =
            authUser.userMetadata?['avatar_url'] as String?;

        return UserModel.fromJson({
          'id': authUser.id,
          'name': nameFromMetadata ?? authUser.email ?? 'User',
          'email': authUser.email,
          'avatar_url': avatarFromMetadata ?? defaultAvatar,
        });
      }

      throw ServerException('No user data available for ID: $id');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Error fetching user data: $e');
      rethrow;
    }
  }

  /// Build responsive success page for OAuth callback
  String _buildSuccessPage() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Authentication Successful</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 16px;
            padding: 48px 32px;
            text-align: center;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            max-width: 480px;
            width: 100%;
            animation: slideUp 0.5s ease-out;
        }
        
        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .success-icon {
            width: 80px;
            height: 80px;
            background: #10B981;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            animation: scaleIn 0.6s ease-out 0.2s both;
        }
        
        @keyframes scaleIn {
            from {
                transform: scale(0);
            }
            to {
                transform: scale(1);
            }
        }
        
        .checkmark {
            width: 32px;
            height: 32px;
            stroke: white;
            stroke-width: 3;
            fill: none;
            stroke-linecap: round;
            stroke-linejoin: round;
        }
        
        h1 {
            color: #1F2937;
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 12px;
            line-height: 1.3;
        }
        
        p {
            color: #6B7280;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 32px;
        }
        
        .close-button {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 14px 32px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            outline: none;
        }
        
        .close-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(102, 126, 234, 0.4);
        }
        
        .close-button:active {
            transform: translateY(0);
        }
        
        .footer {
            margin-top: 24px;
            padding-top: 24px;
            border-top: 1px solid #E5E7EB;
            color: #9CA3AF;
            font-size: 14px;
        }
        
        .brand {
            font-weight: 600;
            color: #667eea;
        }
        
        @media (max-width: 480px) {
            .container {
                padding: 32px 24px;
                margin: 20px;
            }
            
            h1 {
                font-size: 24px;
            }
            
            .success-icon {
                width: 64px;
                height: 64px;
            }
            
            .checkmark {
                width: 24px;
                height: 24px;
            }
        }
        
        @media (prefers-color-scheme: dark) {
            body {
                background: linear-gradient(135deg, #1F2937 0%, #111827 100%);
            }
            
            .container {
                background: #374151;
                color: white;
            }
            
            h1 {
                color: #F9FAFB;
            }
            
            p {
                color: #D1D5DB;
            }
            
            .footer {
                border-top-color: #4B5563;
                color: #9CA3AF;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="success-icon">
            <svg class="checkmark" viewBox="0 0 24 24">
                <polyline points="20,6 9,17 4,12"></polyline>
            </svg>
        </div>
        
        <h1>Login Successful!</h1>
        <p>You have been successfully authenticated. You can now safely close this tab and return to the application.</p>
        
        <button class="close-button" onclick="closeTab()">
            Close This Tab
        </button>
        
        <div class="footer">
            Powered by <span class="brand">musee</span>
        </div>
    </div>
    
    <script>
        function closeTab() {
            // Try multiple methods to close the tab
            if (window.opener) {
                window.close();
            } else {
                // For tabs opened programmatically
                window.open('', '_self', '');
                window.close();
            }
            
            // Fallback: Show message if tab cannot be closed
            setTimeout(() => {
                document.querySelector('.close-button').innerHTML = 'Please close this tab manually';
                document.querySelector('.close-button').disabled = true;
                document.querySelector('.close-button').style.opacity = '0.6';
                document.querySelector('.close-button').style.cursor = 'not-allowed';
            }, 1000);
        }
        
        // Auto-close after 5 seconds if user doesn't click
        setTimeout(() => {
            closeTab();
        }, 5000);
        
        // Add keyboard shortcut (Ctrl+W or Cmd+W)
        document.addEventListener('keydown', (e) => {
            if ((e.ctrlKey || e.metaKey) && e.key === 'w') {
                closeTab();
            }
        });
    </script>
</body>
</html>
''';
  }

  /// Build responsive error page for OAuth callback
  String _buildErrorPage(String errorMessage) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Authentication Error</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 16px;
            padding: 48px 32px;
            text-align: center;
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.1);
            max-width: 480px;
            width: 100%;
            animation: slideUp 0.5s ease-out;
        }
        
        @keyframes slideUp {
            from {
                opacity: 0;
                transform: translateY(30px);
            }
            to {
                opacity: 1;
                transform: translateY(0);
            }
        }
        
        .error-icon {
            width: 80px;
            height: 80px;
            background: #ef4444;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 24px;
            animation: scaleIn 0.6s ease-out 0.2s both;
        }
        
        @keyframes scaleIn {
            from {
                transform: scale(0);
            }
            to {
                transform: scale(1);
            }
        }
        
        .x-mark {
            width: 32px;
            height: 32px;
            stroke: white;
            stroke-width: 3;
            fill: none;
            stroke-linecap: round;
            stroke-linejoin: round;
        }
        
        h1 {
            color: #1F2937;
            font-size: 28px;
            font-weight: 700;
            margin-bottom: 12px;
            line-height: 1.3;
        }
        
        p {
            color: #6B7280;
            font-size: 16px;
            line-height: 1.6;
            margin-bottom: 32px;
        }
        
        .retry-button {
            background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
            color: white;
            border: none;
            padding: 14px 32px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            outline: none;
            margin-right: 12px;
        }
        
        .close-button {
            background: #6B7280;
            color: white;
            border: none;
            padding: 14px 32px;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
            outline: none;
        }
        
        .retry-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(239, 68, 68, 0.4);
        }
        
        .close-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 8px 20px rgba(107, 114, 128, 0.4);
        }
        
        .retry-button:active, .close-button:active {
            transform: translateY(0);
        }
        
        .footer {
            margin-top: 24px;
            padding-top: 24px;
            border-top: 1px solid #E5E7EB;
            color: #9CA3AF;
            font-size: 14px;
        }
        
        .brand {
            font-weight: 600;
            color: #ef4444;
        }
        
        @media (max-width: 480px) {
            .container {
                padding: 32px 24px;
                margin: 20px;
            }
            
            h1 {
                font-size: 24px;
            }
            
            .error-icon {
                width: 64px;
                height: 64px;
            }
            
            .x-mark {
                width: 24px;
                height: 24px;
            }
            
            .retry-button, .close-button {
                display: block;
                width: 100%;
                margin-bottom: 12px;
                margin-right: 0;
            }
        }
        
        @media (prefers-color-scheme: dark) {
            body {
                background: linear-gradient(135deg, #7f1d1d 0%, #991b1b 100%);
            }
            
            .container {
                background: #374151;
                color: white;
            }
            
            h1 {
                color: #F9FAFB;
            }
            
            p {
                color: #D1D5DB;
            }
            
            .footer {
                border-top-color: #4B5563;
                color: #9CA3AF;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="error-icon">
            <svg class="x-mark" viewBox="0 0 24 24">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
            </svg>
        </div>
        
        <h1>Authentication Failed</h1>
        <p>$errorMessage</p>
        
        <button class="retry-button" onclick="retryAuth()">
            Try Again
        </button>
        <button class="close-button" onclick="closeTab()">
            Close Tab
        </button>
        
        <div class="footer">
            Powered by <span class="brand">musee</span>
        </div>
    </div>
    
    <script>
        function retryAuth() {
            window.location.reload();
        }
        
        function closeTab() {
            if (window.opener) {
                window.close();
            } else {
                window.open('', '_self', '');
                window.close();
            }
            
            setTimeout(() => {
                document.querySelector('.close-button').innerHTML = 'Please close this tab manually';
                document.querySelector('.close-button').disabled = true;
                document.querySelector('.close-button').style.opacity = '0.6';
                document.querySelector('.close-button').style.cursor = 'not-allowed';
            }, 1000);
        }
        
        document.addEventListener('keydown', (e) => {
            if ((e.ctrlKey || e.metaKey) && e.key === 'w') {
                closeTab();
            }
        });
    </script>
</body>
</html>
''';
  }
}
