class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  static const accessTokenKey = 'echo_access_token';
  static const refreshTokenKey = 'echo_refresh_token';

  final String accessToken;
  final String refreshToken;
}
