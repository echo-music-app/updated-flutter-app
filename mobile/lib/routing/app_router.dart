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
import 'package:mobile/features/profile_view/domain/use_cases/update_own_profile.dart';
import 'package:mobile/features/profile_view/domain/use_cases/upload_own_avatar.dart';
import 'package:mobile/features/profile_view/presentation/profile_screen.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';
import 'package:mobile/ui/home/echo_home_feed_repository.dart';
import 'package:mobile/ui/home/home_screen.dart';
import 'package:mobile/ui/home/home_view_model.dart';
import 'package:mobile/ui/friends/echo_friends_repository.dart';
import 'package:mobile/ui/friends/friends_repository.dart';
import 'package:mobile/ui/friends/friends_screen.dart';
import 'package:mobile/ui/friends/friends_view_model.dart';
import 'package:mobile/ui/login/login_view_model.dart';
import 'package:mobile/ui/login/login_screen.dart';
import 'package:mobile/ui/login/verify_email_screen.dart';
import 'package:mobile/ui/messages/echo_messages_repository.dart';
import 'package:mobile/ui/messages/messages_screen.dart';
import 'package:mobile/ui/messages/messages_view_model.dart';
import 'package:mobile/ui/player/player_screen.dart';
import 'package:mobile/ui/player/player_view_model.dart';
import 'package:mobile/ui/player_webview/player_webview_screen.dart';
import 'package:mobile/ui/player_webview/player_webview_view_model.dart';
import 'package:mobile/ui/notifications/echo_notifications_repository.dart';
import 'package:mobile/ui/notifications/notifications_screen.dart';
import 'package:mobile/ui/notifications/notifications_view_model.dart';
import 'package:mobile/ui/post/create_post_screen.dart';
import 'package:mobile/ui/post/echo_post_repository.dart';
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
      builder: (ctx, _) => HomeScreen(
        viewModel: HomeViewModel(
          repository: EchoHomeFeedRepository(
            echoBaseUrl: _echoBaseUrl,
            getAccessToken: authRepository.getAccessToken,
            refreshAccessToken: authRepository.refreshAccessToken,
          ),
        ),
      ),
    ),
    GoRoute(
      path: Routes.login,
      builder: (ctx, _) => LoginScreen(viewModel: _buildLoginViewModel(ctx)),
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
      path: Routes.friendsFollowers,
      builder: (ctx, _) => FriendsScreen(
        viewModel: _buildFriendsViewModel(
          ctx,
          authRepository,
          FriendListType.followers,
        ),
        listType: FriendListType.followers,
      ),
    ),
    GoRoute(
      path: Routes.friendsFollowing,
      builder: (ctx, _) => FriendsScreen(
        viewModel: _buildFriendsViewModel(
          ctx,
          authRepository,
          FriendListType.following,
        ),
        listType: FriendListType.following,
      ),
    ),
    GoRoute(
      path: Routes.messages,
      builder: (ctx, _) => MessagesScreen(
        viewModel: _buildMessagesViewModel(ctx, authRepository),
      ),
    ),
    GoRoute(
      path: Routes.messagesUser,
      builder: (ctx, routeState) => MessagesScreen(
        viewModel: _buildMessagesViewModel(ctx, authRepository),
        userId: routeState.pathParameters['userId'],
      ),
    ),
    GoRoute(
      path: Routes.notifications,
      builder: (ctx, _) => NotificationsScreen(
        viewModel: _buildNotificationsViewModel(ctx, authRepository),
      ),
    ),
    GoRoute(
      path: Routes.search,
      builder: (ctx, _) => MusicSearchScreen(
        viewModel: _buildSearchViewModel(ctx, authRepository),
      ),
    ),
    GoRoute(
      path: Routes.createPost,
      builder: (ctx, _) => CreatePostScreen(
        repository: EchoPostRepository(
          echoBaseUrl: _echoBaseUrl,
          getAccessToken: authRepository.getAccessToken,
          refreshAccessToken: authRepository.refreshAccessToken,
        ),
        onAuthExpired: authRepository.clearSession,
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

FriendsViewModel _buildFriendsViewModel(
  BuildContext ctx,
  AuthRepository authRepository,
  FriendListType listType,
) {
  final repo = EchoFriendsRepository(
    echoBaseUrl: _echoBaseUrl,
    getAccessToken: authRepository.getAccessToken,
    refreshAccessToken: authRepository.refreshAccessToken,
  );
  return FriendsViewModel(
    repository: repo,
    listType: listType,
    onAuthExpired: authRepository.clearSession,
  );
}

MessagesViewModel _buildMessagesViewModel(
  BuildContext ctx,
  AuthRepository authRepository,
) {
  final repo = EchoMessagesRepository(
    echoBaseUrl: _echoBaseUrl,
    getAccessToken: authRepository.getAccessToken,
    refreshAccessToken: authRepository.refreshAccessToken,
  );
  return MessagesViewModel(
    repository: repo,
    onAuthExpired: authRepository.clearSession,
  );
}

NotificationsViewModel _buildNotificationsViewModel(
  BuildContext ctx,
  AuthRepository authRepository,
) {
  final repo = EchoNotificationsRepository(
    echoBaseUrl: _echoBaseUrl,
    getAccessToken: authRepository.getAccessToken,
    refreshAccessToken: authRepository.refreshAccessToken,
  );
  return NotificationsViewModel(
    repository: repo,
    onAuthExpired: authRepository.clearSession,
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
    updateOwnProfile: UpdateOwnProfileUseCase(repository: repo),
    uploadOwnAvatar: UploadOwnAvatarUseCase(repository: repo),
    currentUserId: null,
    getFollowStatus: repo.getFollowStatus,
    sendFollowRequest: repo.sendFollowRequest,
    acceptFollowRequest: repo.acceptFollowRequest,
  );
}
