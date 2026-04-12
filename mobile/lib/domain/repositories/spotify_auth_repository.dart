import 'package:flutter/foundation.dart';
import 'package:mobile/domain/models/spotify_session.dart';

abstract class SpotifyAuthRepositoryInterface extends ChangeNotifier {
  bool get isAuthenticated;
  Future<void> startAuth();
  Future<SpotifySession?> handleRedirect(Uri uri);
  Future<String?> getAccessToken();
  Future<void> clearSession();
}
