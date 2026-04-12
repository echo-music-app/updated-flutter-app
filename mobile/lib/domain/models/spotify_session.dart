class SpotifySession {
  const SpotifySession({
    required this.echoAccessToken,
    required this.echoRefreshToken,
  });

  static const accessTokenKey = 'echo_access_token';
  static const refreshTokenKey = 'echo_refresh_token';

  final String echoAccessToken;
  final String echoRefreshToken;
}
