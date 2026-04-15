import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/domain/models/spotify_session.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/domain/repositories/spotify_auth_repository.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/routing/app_router.dart';
import 'package:mobile/ui/core/themes/app_theme.dart';
import 'package:mobile/ui/core/themes/theme_mode_controller.dart';
import 'package:provider/provider.dart';

class _FakeAuthRepository extends AuthRepository {
  bool _isAuthenticated = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get lastLogoutWasLocalOnly => false;

  @override
  bool get supportsTfa => true;

  @override
  Future<String?> getAccessToken() async => 'fake-token';

  @override
  Future<String?> refreshAccessToken() async => 'fake-token';

  @override
  Future<void> logout() async {
    _isAuthenticated = false;
    notifyListeners();
  }

  @override
  Future<void> clearSession() async {
    _isAuthenticated = false;
    notifyListeners();
  }

  @override
  Future<void> loginWithEmail(
    String email,
    String password, {
    String? mfaCode,
  }) async {
    _isAuthenticated = true;
    notifyListeners();
  }

  @override
  Future<PendingVerification> register(
    String email,
    String username,
    String password,
  ) async {
    return PendingVerification(
      email: email,
      message: 'Verification required',
      expiresInSeconds: 900,
    );
  }

  @override
  Future<void> verifyEmail(String email, String code) async {
    _isAuthenticated = true;
    notifyListeners();
  }

  @override
  Future<PendingVerification> resendVerificationCode(String email) async {
    return PendingVerification(
      email: email,
      message: 'Verification required',
      expiresInSeconds: 900,
    );
  }

  @override
  Future<void> loginWithGoogle() async {
    _isAuthenticated = true;
    notifyListeners();
  }
}

class _FakeSpotifyAuthRepository extends SpotifyAuthRepositoryInterface {
  @override
  bool get isAuthenticated => false;

  @override
  Future<void> startAuth() async {}

  @override
  Future<SpotifySession?> handleRedirect(Uri uri) async => null;

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<void> clearSession() async {}
}

Widget _buildApp(_FakeAuthRepository authRepository) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ThemeModeController>(
        create: (_) => ThemeModeController(),
      ),
      ChangeNotifierProvider<AuthRepository>.value(value: authRepository),
      ChangeNotifierProvider<SpotifyAuthRepositoryInterface>(
        create: (_) => _FakeSpotifyAuthRepository(),
      ),
    ],
    child: Builder(
      builder: (context) => MaterialApp.router(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: appRouter(authRepository),
      ),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('successful login redirects to Feed home screen', (tester) async {
    final authRepository = _FakeAuthRepository();
    await tester.pumpWidget(_buildApp(authRepository));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'user@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123!');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Feed'), findsOneWidget);
  });
}
