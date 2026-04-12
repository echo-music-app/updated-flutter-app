import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/domain/repositories/spotify_auth_repository.dart';
import 'package:mobile/routing/routes.dart';
import 'package:mobile/domain/repositories/auth_repository.dart';
import 'package:mobile/domain/repositories/queue_repository_interface.dart';
import 'package:mobile/domain/repositories/track_repository.dart';
import 'package:mobile/features/music_search/data/repositories/echo_music_search_repository.dart';
import 'package:mobile/features/music_search/domain/use_cases/run_music_search.dart';
import 'package:mobile/features/music_search/domain/use_cases/select_search_result_type.dart';
import 'package:mobile/features/music_search/presentation/music_search_screen.dart';
import 'package:mobile/features/music_search/presentation/music_search_view_model.dart';
import 'package:mobile/features/profile_view/data/repositories/echo_profile_repository.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_header.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/use_cases/resolve_profile_target.dart';
import 'package:mobile/features/profile_view/presentation/profile_screen.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';
import 'package:mobile/ui/home/home_screen.dart';
import 'package:mobile/ui/home/home_view_model.dart';
import 'package:mobile/ui/login/login_view_model.dart';
import 'package:mobile/ui/login/login_screen.dart';
import 'package:mobile/ui/login/verify_email_screen.dart';
import 'package:mobile/ui/player/player_screen.dart';
import 'package:mobile/ui/player/player_view_model.dart';
import 'package:mobile/ui/player_webview/player_webview_screen.dart';
import 'package:mobile/ui/player_webview/player_webview_view_model.dart';
import 'package:provider/provider.dart';

const _echoBaseUrl = String.fromEnvironment(
  'ECHO_BASE_URL',
  defaultValue: 'http://10.0.2.2:8001',
);

GoRouter appRouter(AuthRepository authRepository) => GoRouter(
  initialLocation: Routes.home,
  debugLogDiagnostics: true,
  refreshListenable: authRepository,
  redirect: (context, state) {
    final isAuthenticated = authRepository.isAuthenticated;
    final isPublicAuthRoute =
        state.matchedLocation == Routes.login ||
        state.matchedLocation == Routes.verifyEmail;
    if (!isAuthenticated && !isPublicAuthRoute) return Routes.login;
    if (isAuthenticated && isPublicAuthRoute) return Routes.home;
    return null;
  },
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (ctx, _) => HomeScreen(viewModel: HomeViewModel()),
    ),
    GoRoute(
      path: Routes.login,
      builder: (ctx, _) => LoginScreen(
        viewModel: _buildLoginViewModel(ctx),
      ),
    ),
    GoRoute(
      path: Routes.verifyEmail,
      builder: (ctx, routeState) => VerifyEmailScreen(
        viewModel: _buildLoginViewModel(ctx),
        initialEmail: routeState.uri.queryParameters['email'] ?? '',
      ),
    ),
    GoRoute(
      path: Routes.player,
      builder: (ctx, _) => PlayerScreen(
        viewModel: PlayerViewModel(
          queueRepository: ctx.read<QueueRepository>(),
        ),
      ),
    ),
    GoRoute(
      path: Routes.playerWebView,
      builder: (ctx, _) => PlayerWebViewScreen(
        viewModel: PlayerWebViewViewModel(
          queueRepository: ctx.read<QueueRepository>(),
          trackRepository: ctx.read<TrackRepository>(),
        ),
      ),
    ),
    GoRoute(
      path: Routes.search,
      builder: (ctx, _) => MusicSearchScreen(
        viewModel: _buildSearchViewModel(ctx, authRepository),
      ),
    ),
    GoRoute(
      path: Routes.profile,
      builder: (ctx, routeState) =>
          ProfileScreen(viewModel: _buildProfileViewModel(ctx, authRepository)),
    ),
    GoRoute(
      path: Routes.profileUser,
      builder: (ctx, routeState) => ProfileScreen(
        viewModel: _buildProfileViewModel(ctx, authRepository),
        userId: routeState.pathParameters['userId'],
      ),
    ),
  ],
);

LoginViewModel _buildLoginViewModel(BuildContext ctx) {
  return LoginViewModel(
    authRepository: ctx.read<AuthRepository>(),
    spotifyAuthRepository: ctx.read<SpotifyAuthRepositoryInterface>(),
  );
}

MusicSearchViewModel _buildSearchViewModel(
  BuildContext ctx,
  AuthRepository authRepository,
) {
  final repo = EchoMusicSearchRepository(
    echoBaseUrl: _echoBaseUrl,
    getAccessToken: authRepository.getAccessToken,
    refreshAccessToken: authRepository.refreshAccessToken,
  );
  return MusicSearchViewModel(
    runSearch: RunMusicSearchUseCase(repository: repo),
    selectType: const SelectSearchResultTypeUseCase(),
    onAuthExpired: authRepository.clearSession,
  );
}

ProfileViewModel _buildProfileViewModel(
  BuildContext ctx,
  AuthRepository authRepository,
) {
  final repo = EchoProfileRepository(
    echoBaseUrl: _echoBaseUrl,
    getAccessToken: authRepository.getAccessToken,
    refreshAccessToken: authRepository.refreshAccessToken,
  );
  return ProfileViewModel(
    resolveTarget: const ResolveProfileTargetUseCase(),
    loadHeader: LoadProfileHeaderUseCase(repository: repo),
    loadPostsPage: LoadProfilePostsPageUseCase(repository: repo),
    currentUserId: null,
  );
}
