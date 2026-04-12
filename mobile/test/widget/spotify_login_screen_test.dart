import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/models/spotify_session.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/domain/repositories/spotify_auth_repository.dart';
import 'package:mobile/ui/login/login_view_model.dart';
import 'package:mobile/ui/login/spotify_login_screen.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

Widget _wrapWithMaterialApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

class _FakeAuthRepository extends AuthRepository {
  @override
  bool get isAuthenticated => false;

  @override
  bool get supportsTfa => false;

  @override
  Future<String?> getAccessToken() async => null;

  @override
  Future<String?> refreshAccessToken() async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<void> clearSession() async {}

  @override
  Future<void> loginWithEmail(String email, String password) {
    throw UnimplementedError();
  }

  @override
  Future<PendingVerification> register(
    String email,
    String username,
    String password,
  ) async {
    return PendingVerification(
      email: email,
      message: 'Check your email',
      expiresInSeconds: 900,
    );
  }

  @override
  Future<void> verifyEmail(String email, String code) {
    throw UnimplementedError();
  }

  @override
  Future<PendingVerification> resendVerificationCode(String email) async {
    return PendingVerification(
      email: email,
      message: 'Check your email',
      expiresInSeconds: 900,
    );
  }

  @override
  Future<void> loginWithGoogle() {
    throw UnimplementedError();
  }
}

class _FakeSpotifyAuthRepository extends SpotifyAuthRepositoryInterface {
  _FakeSpotifyAuthRepository({FutureOr<void> Function()? onStartAuth})
    : _onStartAuth = onStartAuth;

  final FutureOr<void> Function()? _onStartAuth;

  @override
  bool get isAuthenticated => false;

  @override
  Future<void> startAuth() async {
    if (_onStartAuth != null) await _onStartAuth();
  }

  @override
  Future<SpotifySession?> handleRedirect(Uri uri) async => null;

  @override
  Future<void> clearSession() async {}

  @override
  Future<String?> getAccessToken() {
    throw UnimplementedError();
  }
}

void main() {
  group('SpotifyLoginScreen', () {
    testWidgets('shows "Connect with Spotify" button', (tester) async {
      final viewModel = LoginViewModel(
        authRepository: _FakeAuthRepository(),
        spotifyAuthRepository: _FakeSpotifyAuthRepository(),
      );
      await tester.pumpWidget(
        _wrapWithMaterialApp(SpotifyLoginScreen(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connect with Spotify'), findsOneWidget);
    });

    testWidgets('tap triggers startAuth callback', (tester) async {
      var pressed = false;
      final viewModel = LoginViewModel(
        authRepository: _FakeAuthRepository(),
        spotifyAuthRepository: _FakeSpotifyAuthRepository(
          onStartAuth: () => pressed = true,
        ),
      );
      await tester.pumpWidget(
        _wrapWithMaterialApp(SpotifyLoginScreen(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect with Spotify'));
      await tester.pump();
      expect(pressed, isTrue);
    });

    testWidgets('shows loading indicator when isLoading is true', (
      tester,
    ) async {
      final authCompleter = Completer<void>();
      final viewModel = LoginViewModel(
        authRepository: _FakeAuthRepository(),
        spotifyAuthRepository: _FakeSpotifyAuthRepository(
          onStartAuth: () => authCompleter.future,
        ),
      );
      await tester.pumpWidget(
        _wrapWithMaterialApp(SpotifyLoginScreen(viewModel: viewModel)),
      );
      await tester.pumpAndSettle();

      unawaited(viewModel.connectWithSpotify());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
