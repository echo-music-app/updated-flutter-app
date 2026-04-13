import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/domain/models/auth_tokens.dart';
import 'package:mobile/domain/models/spotify_session.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';

class EmailAuthRepository extends ChangeNotifier implements AuthRepository {
  EmailAuthRepository({
    required String echoBaseUrl,
    String? googleClientId,
    String? googleServerClientId,
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  }) : _echoBaseUrl = echoBaseUrl,
       _googleSignIn = GoogleSignIn.instance,
       _googleClientId = googleClientId ?? '',
       _googleServerClientId = googleServerClientId ?? '',
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _dio = dio ?? Dio() {
    _init();
  }

  final String _echoBaseUrl;
  final GoogleSignIn _googleSignIn;
  final String _googleClientId;
  final String _googleServerClientId;
  final FlutterSecureStorage _secureStorage;
  final Dio _dio;

  bool _isAuthenticated = false;
  bool _lastLogoutWasLocalOnly = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  bool get lastLogoutWasLocalOnly => _lastLogoutWasLocalOnly;

  @override
  bool get supportsTfa => true;

  Future<void> _init() async {
    final hasActiveSession = await hasSession();
    if (_isAuthenticated == hasActiveSession) return;
    _isAuthenticated = hasActiveSession;
    // Defer notification until after first frame to avoid provider rebuild
    // during widget tree mount.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Check whether an Echo session exists in secure storage.
  Future<bool> hasSession() async {
    final token = await _secureStorage.read(key: SpotifySession.accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> _storeTokens(AuthTokens tokens) async {
    await _secureStorage.write(
      key: AuthTokens.accessTokenKey,
      value: tokens.accessToken,
    );
    await _secureStorage.write(
      key: AuthTokens.refreshTokenKey,
      value: tokens.refreshToken,
    );
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<AuthTokens> _parseAndStoreTokens(Map<String, dynamic> data) async {
    final tokens = AuthTokens(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );
    await _storeTokens(tokens);
    return tokens;
  }

  /// Login with email and password using the backend endpoint.
  @override
  Future<void> loginWithEmail(
    String email,
    String password, {
    String? mfaCode,
  }) async {
    try {
      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/login',
        data: FormData.fromMap({
          'username': email,
          'password': password,
          'grant_type': 'password',
        }),
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            if (mfaCode != null && mfaCode.trim().isNotEmpty)
              'X-MFA-Code': mfaCode.trim(),
          },
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Login failed: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      await _parseAndStoreTokens(data);
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['detail'] ?? 'Login failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  /// Register a new user with email, username, and password.
  @override
  Future<PendingVerification> register(
    String email,
    String username,
    String password,
  ) async {
    try {
      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/register',
        data: {'email': email, 'username': username, 'password': password},
      );

      if (response.statusCode != 201) {
        throw Exception('Registration failed: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      return PendingVerification(
        email: email,
        message:
            (data['message'] as String?) ??
            'Check your email for a verification code',
        expiresInSeconds: (data['verification_expires_in'] as int?) ?? 900,
        debugCode: data['verification_code'] as String?,
      );
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['detail'] ?? 'Registration failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  @override
  Future<void> verifyEmail(String email, String code) async {
    try {
      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/verify-email',
        data: {'email': email, 'code': code},
      );
      if (response.statusCode != 200) {
        throw Exception('Verification failed: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      await _parseAndStoreTokens(data);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data?['detail'] ?? 'Email verification failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Email verification failed: $e');
    }
  }

  @override
  Future<PendingVerification> resendVerificationCode(String email) async {
    try {
      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/resend-verification',
        data: {'email': email},
      );

      if (response.statusCode != 200) {
        throw Exception('Could not resend code: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      return PendingVerification(
        email: email,
        message:
            (data['message'] as String?) ??
            'If the account exists, a new code was sent.',
        expiresInSeconds: (data['verification_expires_in'] as int?) ?? 900,
        debugCode: data['verification_code'] as String?,
      );
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['detail'] ?? 'Could not resend';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Could not resend code: $e');
    }
  }

  @override
  Future<void> loginWithGoogle() async {
    try {
      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      if (isAndroid && _googleServerClientId.isEmpty) {
        throw Exception(
          'Google sign-in is not configured. Provide --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.',
        );
      }

      if (_googleClientId.isNotEmpty || _googleServerClientId.isNotEmpty) {
        await _googleSignIn.initialize(
          clientId: _googleClientId.isEmpty ? null : _googleClientId,
          serverClientId: _googleServerClientId.isEmpty
              ? null
              : _googleServerClientId,
        );
      } else {
        await _googleSignIn.initialize();
      }

      final account = await _googleSignIn.authenticate();
      final auth = account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google ID token is missing');
      }

      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/google',
        data: {'id_token': idToken},
      );
      if (response.statusCode != 200) {
        throw Exception('Google login failed: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      await _parseAndStoreTokens(data);
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['detail'] ?? 'Google login failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Google login failed: $e');
    }
  }

  /// Read the stored Echo access token.
  @override
  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: AuthTokens.accessTokenKey);
  }

  @override
  Future<String?> refreshAccessToken() async {
    final refreshToken = await _secureStorage.read(
      key: AuthTokens.refreshTokenKey,
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      await clearSession();
      return null;
    }

    try {
      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/refresh-token',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode != 200) {
        throw Exception('Refresh failed: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final tokens = await _parseAndStoreTokens(data);
      return tokens.accessToken;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await clearSession();
        return null;
      }
      final errorMessage =
          e.response?.data?['detail'] ?? 'Token refresh failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Token refresh failed: $e');
    }
  }

  @override
  Future<void> logout() async {
    _lastLogoutWasLocalOnly = false;
    final accessToken = await _secureStorage.read(
      key: AuthTokens.accessTokenKey,
    );
    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        await _dio.post(
          '$_echoBaseUrl/v1/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );
      } on DioException catch (e) {
        // Do not block local sign-out on server/network logout failures.
        // Tokens are still cleared locally below.
        _lastLogoutWasLocalOnly = true;
        debugPrint('Logout API failed: ${e.response?.statusCode} ${e.message}');
      }
    }
    await clearSession();
  }

  /// Clear stored tokens (logout).
  @override
  Future<void> clearSession() async {
    await _secureStorage.delete(key: AuthTokens.accessTokenKey);
    await _secureStorage.delete(key: AuthTokens.refreshTokenKey);
    _isAuthenticated = false;
    notifyListeners();
  }
}
