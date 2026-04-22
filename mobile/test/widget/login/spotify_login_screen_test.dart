// T019: Widget tests for SpotifyLoginScreen with LoginViewModel.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/ui/login/login_view_model.dart';
import 'package:mobile/ui/login/spotify_login_screen.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
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
  _FakeAuthRepository({FutureOr<void> Function()? onSpotifyLogin})
    : _onSpotifyLogin = onSpotifyLogin;

  final FutureOr<void> Function()? _onSpotifyLogin;

  @override
  bool get isAuthenticated => false;

  @override
  bool get lastLogoutWasLocalOnly => false;

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
  Future<void> loginWithEmail(
    String email,
    String password, {
    String? mfaCode,
  }) {
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
  Future<void> loginWithApple() {
    throw UnimplementedError();
  }

  @override
  Future<void> loginWithSoundCloud() {
    throw UnimplementedError();
  }

  @override
  Future<void> loginWithSpotify() async {
    if (_onSpotifyLogin != null) await _onSpotifyLogin();
  }
}

void main() {
  group('SpotifyLoginScreen — pre-auth state', () {
    testWidgets(
      'shows "Connect with Spotify" button when not yet authenticated',
      (tester) async {
        final viewModel = LoginViewModel(authRepository: _FakeAuthRepository());
        await tester.pumpWidget(
          _wrap(SpotifyLoginScreen(viewModel: viewModel)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Connect with Spotify'), findsOneWidget);
      },
    );

    testWidgets('shows loading indicator during OAuth flow', (tester) async {
      // Use a Completer-based fake so startAuth never resolves during the test.
      final authCompleter = Completer<void>();
      final viewModel = LoginViewModel(
        authRepository: _FakeAuthRepository(
          onSpotifyLogin: () => authCompleter.future,
        ),
      );
      await tester.pumpWidget(_wrap(SpotifyLoginScreen(viewModel: viewModel)));
      await tester.pumpAndSettle();

      // Tap the button to trigger loading (don't await — it never resolves).
      unawaited(viewModel.connectWithSpotify());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('"Connect with Spotify" tap invokes connectWithSpotify', (
      tester,
    ) async {
      var connectCalled = false;
      final viewModel = LoginViewModel(
        authRepository: _FakeAuthRepository(
          onSpotifyLogin: () => connectCalled = true,
        ),
      );
      await tester.pumpWidget(_wrap(SpotifyLoginScreen(viewModel: viewModel)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect with Spotify'));
      await tester.pump();

      expect(connectCalled, isTrue);
    });
  });
}
