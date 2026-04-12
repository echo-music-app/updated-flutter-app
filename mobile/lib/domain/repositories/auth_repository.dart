import 'package:flutter/foundation.dart';

class PendingVerification {
  const PendingVerification({
    required this.email,
    required this.message,
    required this.expiresInSeconds,
    this.debugCode,
  });

  final String email;
  final String message;
  final int expiresInSeconds;
  final String? debugCode;
}

abstract class AuthRepository extends ChangeNotifier {
  bool get isAuthenticated;
  Future<String?> getAccessToken();
  Future<String?> refreshAccessToken();
  Future<void> logout();
  Future<void> clearSession();
  bool get supportsTfa;

  // Email authentication methods
  Future<void> loginWithEmail(String email, String password);
  Future<PendingVerification> register(
    String email,
    String username,
    String password,
  );
  Future<void> verifyEmail(String email, String code);
  Future<PendingVerification> resendVerificationCode(String email);
  Future<void> loginWithGoogle();
}
