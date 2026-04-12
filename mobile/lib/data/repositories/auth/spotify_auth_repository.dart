import 'dart:convert';
import 'dart:math';

import 'package:app_links/app_links.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/domain/models/spotify_session.dart';
import 'package:mobile/domain/repositories/spotify_auth_repository.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotifyAuthRepository extends ChangeNotifier
    implements SpotifyAuthRepositoryInterface {
  SpotifyAuthRepository({
    required String echoBaseUrl,
    required String spotifyClientId,
    required String spotifyRedirectUri,
    FlutterSecureStorage? secureStorage,
    Dio? dio,
  }) : _echoBaseUrl = echoBaseUrl,
       _spotifyClientId = spotifyClientId,
       _spotifyRedirectUri = spotifyRedirectUri,
       _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _dio = dio ?? Dio() {
    _init();
  }

  final String _echoBaseUrl;
  final String _spotifyClientId;
  final String _spotifyRedirectUri;
  final FlutterSecureStorage _secureStorage;
  final Dio _dio;

  String? _codeVerifier;
  bool _isAuthenticated = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  Future<void> _init() async {
    _isAuthenticated = await hasSession();
    notifyListeners();
    AppLinks().uriLinkStream.listen((uri) async {
      await handleRedirect(uri);
    });
  }

  /// Check whether an Echo session exists in secure storage.
  Future<bool> hasSession() async {
    final token = await _secureStorage.read(key: SpotifySession.accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  /// Start the Spotify OAuth PKCE flow by opening the browser.
  @override
  Future<void> startAuth() async {
    _codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(_codeVerifier!);

    final uri = Uri.https('accounts.spotify.com', '/authorize', {
      'client_id': _spotifyClientId,
      'response_type': 'code',
      'redirect_uri': _spotifyRedirectUri,
      'code_challenge_method': 'S256',
      'code_challenge': codeChallenge,
      'scope': 'user-read-private user-read-email streaming',
    });

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Listen for the OAuth redirect and exchange the code for Echo tokens.
  @override
  Future<SpotifySession?> handleRedirect(Uri uri) async {
    final code = uri.queryParameters['code'];
    if (code == null || _codeVerifier == null) return null;

    final response = await _dio.post(
      '$_echoBaseUrl/v1/auth/spotify/token',
      data: {
        'code': code,
        'code_verifier': _codeVerifier,
        'redirect_uri': _spotifyRedirectUri,
      },
    );

    if (response.statusCode != 200) return null;

    final data = response.data as Map<String, dynamic>;
    final session = SpotifySession(
      echoAccessToken: data['access_token'] as String,
      echoRefreshToken: data['refresh_token'] as String,
    );

    await _secureStorage.write(
      key: SpotifySession.accessTokenKey,
      value: session.echoAccessToken,
    );
    await _secureStorage.write(
      key: SpotifySession.refreshTokenKey,
      value: session.echoRefreshToken,
    );

    _codeVerifier = null;
    _isAuthenticated = true;
    notifyListeners();
    return session;
  }

  /// Read the stored Echo access token.
  @override
  Future<String?> getAccessToken() async {
    return _secureStorage.read(key: SpotifySession.accessTokenKey);
  }

  /// Clear stored tokens (logout).
  @override
  Future<void> clearSession() async {
    await _secureStorage.delete(key: SpotifySession.accessTokenKey);
    await _secureStorage.delete(key: SpotifySession.refreshTokenKey);
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
