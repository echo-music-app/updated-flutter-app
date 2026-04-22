import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/domain/models/auth_tokens.dart';
import 'package:mobile/domain/models/spotify_session.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

class EmailAuthRepository extends ChangeNotifier implements AuthRepository {
  EmailAuthRepository({
    required String echoBaseUrl,
    String? spotifyClientId,
    String? spotifyRedirectUri,
    String? appleClientId,
    String? appleRedirectUri,
    String? soundCloudClientId,
    String? soundCloudRedirectUri,
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  }) : _echoBaseUrl = echoBaseUrl,
       _spotifyClientId = spotifyClientId ?? '',
       _spotifyRedirectUri = spotifyRedirectUri ?? '',
       _appleClientId = appleClientId ?? '',
       _appleRedirectUri = appleRedirectUri ?? '',
       _soundCloudClientId = soundCloudClientId ?? '',
       _soundCloudRedirectUri = soundCloudRedirectUri ?? '',
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _dio = dio ?? Dio() {
    _init();
  }

  final String _echoBaseUrl;
  final String _spotifyClientId;
  final String _spotifyRedirectUri;
  final String _appleClientId;
  final String _appleRedirectUri;
  final String _soundCloudClientId;
  final String _soundCloudRedirectUri;
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
  Future<void> loginWithSpotify() async {
    try {
      if (_spotifyClientId.isEmpty || _spotifyRedirectUri.isEmpty) {
        throw Exception(
          'Spotify login is not configured. Provide SPOTIFY_CLIENT_ID and SPOTIFY_REDIRECT_URI.',
        );
      }

      final codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(codeVerifier);

      final authUri = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': _spotifyClientId,
        'response_type': 'code',
        'redirect_uri': _spotifyRedirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'scope': 'user-read-private user-read-email streaming',
      });

      final redirectFuture = AppLinks().uriLinkStream
          .firstWhere((uri) => uri.queryParameters['code'] != null)
          .timeout(const Duration(minutes: 2));

      await launchUrl(authUri, mode: LaunchMode.externalApplication);
      final redirectUri = await redirectFuture;
      final code = redirectUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw Exception('Spotify authorization code is missing');
      }

      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/spotify/token',
        data: {
          'code': code,
          'code_verifier': codeVerifier,
          'redirect_uri': _spotifyRedirectUri,
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Spotify login failed: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      await _parseAndStoreTokens(data);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data?['detail'] ?? 'Spotify login failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Spotify login failed: $e');
    }
  }

  @override
  Future<void> loginWithApple() async {
    try {
      final isApplePlatform =
          !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS);

      late final AuthorizationCredentialAppleID credential;
      if (isApplePlatform) {
        credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
      } else {
        if (_appleClientId.isEmpty || _appleRedirectUri.isEmpty) {
          throw Exception(
            'Apple sign-in is not configured for this platform. Provide APPLE_CLIENT_ID and APPLE_REDIRECT_URI.',
          );
        }
        credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
          webAuthenticationOptions: WebAuthenticationOptions(
            clientId: _appleClientId,
            redirectUri: Uri.parse(_appleRedirectUri),
          ),
        );
      }

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Apple ID token is missing');
      }

      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/apple',
        data: {'id_token': idToken},
      );
      if (response.statusCode != 200) {
        throw Exception('Apple login failed: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      await _parseAndStoreTokens(data);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw Exception('Apple sign-in was canceled');
      }
      throw Exception('Apple login failed: ${e.code.name}');
    } on DioException catch (e) {
      final errorMessage = e.response?.data?['detail'] ?? 'Apple login failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Apple login failed: $e');
    }
  }

  @override
  Future<void> loginWithSoundCloud() async {
    try {
      if (_soundCloudClientId.isEmpty || _soundCloudRedirectUri.isEmpty) {
        throw Exception(
          'SoundCloud login is not configured. Provide SOUNDCLOUD_CLIENT_ID and SOUNDCLOUD_REDIRECT_URI.',
        );
      }

      final authUri = Uri.https('secure.soundcloud.com', '/authorize', {
        'client_id': _soundCloudClientId,
        'redirect_uri': _soundCloudRedirectUri,
        'response_type': 'code',
        'scope': 'non-expiring',
      });

      final redirectFuture = AppLinks().uriLinkStream
          .firstWhere((uri) => uri.queryParameters['code'] != null)
          .timeout(const Duration(minutes: 2));

      await launchUrl(authUri, mode: LaunchMode.externalApplication);
      final redirectUri = await redirectFuture;
      final code = redirectUri.queryParameters['code'];
      if (code == null || code.isEmpty) {
        throw Exception('SoundCloud authorization code is missing');
      }

      final response = await _dio.post(
        '$_echoBaseUrl/v1/auth/soundcloud/token',
        data: {'code': code, 'redirect_uri': _soundCloudRedirectUri},
      );
      if (response.statusCode != 200) {
        throw Exception('SoundCloud login failed: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      await _parseAndStoreTokens(data);
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data?['detail'] ?? 'SoundCloud login failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('SoundCloud login failed: $e');
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

  static String _generateCodeVerifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(64, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '').substring(0, 128);
  }

  static String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
