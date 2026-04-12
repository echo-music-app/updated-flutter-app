import 'package:mobile/data/repositories/auth/email_auth_repository.dart';
import 'package:mobile/data/repositories/auth/spotify_auth_repository.dart';
import 'package:mobile/data/repositories/queue/spotify_queue_repository.dart';
import 'package:mobile/data/repositories/track/spotify_track_repository.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/domain/repositories/queue_repository_interface.dart';
import 'package:mobile/domain/repositories/spotify_auth_repository.dart';
import 'package:mobile/domain/repositories/track_repository.dart';
import 'package:mobile/features/music_search/data/repositories/echo_music_search_repository.dart';
import 'package:mobile/features/music_search/domain/ports/music_search_repository.dart';
import 'package:mobile/features/profile_view/data/repositories/echo_profile_repository.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

const _echoBaseUrl = String.fromEnvironment(
  'ECHO_BASE_URL',
  defaultValue: 'http://10.0.2.2:8001',
);
const _spotifyClientId = String.fromEnvironment(
  'SPOTIFY_CLIENT_ID',
  defaultValue: 'db80c8b3888e4ba6bd5b0b63658a55b1',
);
const _spotifyRedirectUri = String.fromEnvironment(
  'SPOTIFY_REDIRECT_URI',
  defaultValue: 'echo-auth://callback',
);
const _googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');

List<SingleChildWidget> get providersLocal => [
  ChangeNotifierProvider<AuthRepository>(
    create: (_) => EmailAuthRepository(
      echoBaseUrl: _echoBaseUrl,
      googleClientIds: _googleClientId.isEmpty ? null : [_googleClientId],
    ),
  ),
  ChangeNotifierProvider<SpotifyAuthRepositoryInterface>(
    create: (_) => SpotifyAuthRepository(
      echoBaseUrl: _echoBaseUrl,
      spotifyClientId: _spotifyClientId,
      spotifyRedirectUri: _spotifyRedirectUri,
    ),
  ),
  ProxyProvider<AuthRepository, TrackRepository>(
    update: (_, auth, prev) => SpotifyTrackRepositoryImpl(
      echoBaseUrl: _echoBaseUrl,
      getAccessToken: auth.getAccessToken,
      refreshAccessToken: auth.refreshAccessToken,
    ),
  ),
  ProxyProvider<TrackRepository, QueueRepository>(
    update: (_, trackRepo, prev) =>
        SpotifyQueueRepositoryImpl(trackRepository: trackRepo),
  ),
  ProxyProvider<AuthRepository, ProfileRepository>(
    update: (_, auth, prev) => EchoProfileRepository(
      echoBaseUrl: _echoBaseUrl,
      getAccessToken: auth.getAccessToken,
      refreshAccessToken: auth.refreshAccessToken,
    ),
  ),
  ProxyProvider<AuthRepository, MusicSearchRepository>(
    update: (_, auth, prev) => EchoMusicSearchRepository(
      echoBaseUrl: _echoBaseUrl,
      getAccessToken: auth.getAccessToken,
      refreshAccessToken: auth.refreshAccessToken,
    ),
  ),
];

// providersRemote: same with production URLs (placeholder for now)
List<SingleChildWidget> get providersRemote => providersLocal;
