import 'package:flutter/foundation.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/domain/repositories/spotify_auth_repository.dart';
import 'package:mobile/utils/command.dart';
import 'package:mobile/utils/result.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({
    required AuthRepository authRepository,
    SpotifyAuthRepositoryInterface? spotifyAuthRepository,
  }) : _auth = authRepository,
       _spotifyAuth = spotifyAuthRepository {
    _loginCmd =
        Command1<void, ({String email, String password, String? mfaCode})>(
          _loginFn,
        );
    _registerCmd =
        Command1<void, ({String email, String username, String password})>(
          _registerFn,
        );
    _connectCmd = Command0<void>(_connectFn);
    _googleCmd = Command0<void>(_googleFn);
    _verifyEmailCmd = Command1<void, ({String email, String code})>(
      _verifyEmailFn,
    );
    _resendVerificationCmd = Command1<void, String>(_resendVerificationFn);
    _loginCmd.addListener(notifyListeners);
    _registerCmd.addListener(notifyListeners);
    _connectCmd.addListener(notifyListeners);
    _googleCmd.addListener(notifyListeners);
    _verifyEmailCmd.addListener(notifyListeners);
    _resendVerificationCmd.addListener(notifyListeners);
  }

  final AuthRepository _auth;
  final SpotifyAuthRepositoryInterface? _spotifyAuth;
  late final Command1<void, ({String email, String password, String? mfaCode})>
  _loginCmd;
  late final Command1<void, ({String email, String username, String password})>
  _registerCmd;
  late final Command0<void> _connectCmd;
  late final Command0<void> _googleCmd;
  late final Command1<void, ({String email, String code})> _verifyEmailCmd;
  late final Command1<void, String> _resendVerificationCmd;

  PendingVerification? _pendingVerification;
  bool _mfaRequired = false;

  bool get isAuthenticated => _auth.isAuthenticated;
  bool get supportsTfa => _auth.supportsTfa;
  PendingVerification? get pendingVerification => _pendingVerification;
  bool get mfaRequired => _mfaRequired;

  bool get isLoading =>
      _loginCmd.running ||
      _registerCmd.running ||
      _connectCmd.running ||
      _googleCmd.running ||
      _verifyEmailCmd.running ||
      _resendVerificationCmd.running;

  String? get error {
    if (_loginCmd.hasError) return (_loginCmd.result as Err).error.toString();
    if (_registerCmd.hasError) {
      return (_registerCmd.result as Err).error.toString();
    }
    if (_connectCmd.hasError) {
      return (_connectCmd.result as Err).error.toString();
    }
    if (_googleCmd.hasError) return (_googleCmd.result as Err).error.toString();
    if (_verifyEmailCmd.hasError) {
      return (_verifyEmailCmd.result as Err).error.toString();
    }
    if (_resendVerificationCmd.hasError) {
      return (_resendVerificationCmd.result as Err).error.toString();
    }
    return null;
  }

  Future<void> loginWithEmail(
    String email,
    String password, {
    String? mfaCode,
  }) => _loginCmd.execute((email: email, password: password, mfaCode: mfaCode));

  Future<void> register(String email, String username, String password) =>
      _registerCmd.execute((
        email: email,
        username: username,
        password: password,
      ));

  Future<void> connectWithSpotify() => _connectCmd.execute();
  Future<void> loginWithGoogle() => _googleCmd.execute();
  Future<void> verifyEmail(String email, String code) =>
      _verifyEmailCmd.execute((email: email, code: code));
  Future<void> resendVerificationCode(String email) =>
      _resendVerificationCmd.execute(email);

  Future<Result<void>> _loginFn(
    ({String email, String password, String? mfaCode}) c,
  ) async {
    try {
      await _auth.loginWithEmail(c.email, c.password, mfaCode: c.mfaCode);
      _pendingVerification = null;
      _mfaRequired = false;
      return Result.ok(null);
    } on Exception catch (e) {
      if (e.toString().toLowerCase().contains('email not verified')) {
        _mfaRequired = false;
        _pendingVerification = PendingVerification(
          email: c.email,
          message: 'Email not verified. Please enter the verification code.',
          expiresInSeconds: 900,
        );
      } else if (e.toString().toLowerCase().contains('mfa code required') ||
          e.toString().toLowerCase().contains('invalid mfa code')) {
        _pendingVerification = null;
        _mfaRequired = true;
      }
      return Result.error(e);
    }
  }

  Future<Result<void>> _registerFn(
    ({String email, String username, String password}) c,
  ) async {
    try {
      _mfaRequired = false;
      _pendingVerification = await _auth.register(
        c.email,
        c.username,
        c.password,
      );
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  Future<Result<void>> _connectFn() async {
    try {
      await _spotifyAuth?.startAuth();
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  Future<Result<void>> _googleFn() async {
    try {
      await _auth.loginWithGoogle();
      _pendingVerification = null;
      _mfaRequired = false;
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  Future<Result<void>> _verifyEmailFn(({String email, String code}) c) async {
    try {
      await _auth.verifyEmail(c.email, c.code);
      _pendingVerification = null;
      _mfaRequired = false;
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  Future<Result<void>> _resendVerificationFn(String email) async {
    try {
      _mfaRequired = false;
      _pendingVerification = await _auth.resendVerificationCode(email);
      return Result.ok(null);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  @override
  void dispose() {
    _loginCmd.removeListener(notifyListeners);
    _registerCmd.removeListener(notifyListeners);
    _connectCmd.removeListener(notifyListeners);
    _googleCmd.removeListener(notifyListeners);
    _verifyEmailCmd.removeListener(notifyListeners);
    _resendVerificationCmd.removeListener(notifyListeners);
    super.dispose();
  }
}
