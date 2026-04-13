import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile_view/domain/entities/profile.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/ports/profile_repository.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_header.dart';
import 'package:mobile/features/profile_view/domain/use_cases/load_profile_posts_page.dart';
import 'package:mobile/features/profile_view/domain/use_cases/resolve_profile_target.dart';
import 'package:mobile/features/profile_view/domain/use_cases/update_own_profile.dart';
import 'package:mobile/features/profile_view/domain/use_cases/upload_own_avatar.dart';
import 'package:mobile/features/profile_view/presentation/profile_screen.dart';
import 'package:mobile/features/profile_view/presentation/profile_view_model.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_theme.dart';

// --- Helpers ---

Widget _wrap(Widget child, {ThemeData? theme}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    darkTheme: AppTheme.dark,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

class _StubRepo implements ProfileRepository {
  final ProfileHeader Function()? _ownProfile;
  final Object? ownError;
  final ProfilePostsPage Function()? _ownPosts;
  final Object? postsError;

  const _StubRepo({
    ProfileHeader Function()? ownProfile,
    this.ownError,
    ProfilePostsPage Function()? ownPosts,
    this.postsError,
  }) : _ownProfile = ownProfile,
       _ownPosts = ownPosts;

  @override
  Future<ProfileHeader> getOwnProfile() async {
    if (ownError != null) throw ownError!;
    return _ownProfile!();
  }

  @override
  Future<ProfileHeader> getUserProfile(String userId) async {
    if (ownError != null) throw ownError!;
    return _ownProfile!();
  }

  @override
  Future<ProfilePostsPage> getOwnPosts({
    int pageSize = 20,
    String? cursor,
  }) async {
    if (postsError != null) throw postsError!;
    return _ownPosts!();
  }

  @override
  Future<ProfilePostsPage> getUserPosts(
    String userId, {
    int pageSize = 20,
    String? cursor,
  }) async {
    if (postsError != null) throw postsError!;
    return _ownPosts!();
  }

  @override
  Future<ProfileHeader> updateOwnProfile({String? bio}) async {
    if (ownError != null) throw ownError!;
    return _ownProfile!();
  }

  @override
  Future<ProfileHeader> uploadOwnAvatar(String filePath) async {
    if (ownError != null) throw ownError!;
    return _ownProfile!();
  }
}

ProfileViewModel _vm(_StubRepo repo, {String? currentUserId}) {
  return ProfileViewModel(
    resolveTarget: const ResolveProfileTargetUseCase(),
    loadHeader: LoadProfileHeaderUseCase(repository: repo),
    loadPostsPage: LoadProfilePostsPageUseCase(repository: repo),
    updateOwnProfile: UpdateOwnProfileUseCase(repository: repo),
    uploadOwnAvatar: UploadOwnAvatarUseCase(repository: repo),
    currentUserId: currentUserId,
  );
}

ProfileHeader _header() => ProfileHeader(
  id: 'uid-1',
  username: 'alice',
  bio: 'Producer',
  preferredGenres: ['house', 'ambient'],
  isArtist: true,
  createdAt: DateTime(2026),
);

ProfilePostsPage _emptyPage() =>
    const ProfilePostsPage(items: [], pageSize: 20, count: 0);

ProfilePostSummary _post(String id) => ProfilePostSummary(
  id: id,
  userId: 'uid-1',
  privacy: 'Public',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('ProfileScreen — loading state', () {
    testWidgets('shows loading indicator initially', (tester) async {
      final repo = _StubRepo(
        ownProfile: () => throw StateError('should not complete'),
        ownPosts: () => throw StateError('should not complete'),
      );
      final vm = _vm(repo);
      // Don't await loadProfile so we can see the loading state
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });
  });

  group('ProfileScreen — data state', () {
    testWidgets('renders username and bio after successful load', (
      tester,
    ) async {
      final repo = _StubRepo(ownProfile: _header, ownPosts: _emptyPage);
      final vm = _vm(repo);
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
      expect(find.text('Producer'), findsOneWidget);
    });

    testWidgets('renders genre chips', (tester) async {
      final repo = _StubRepo(ownProfile: _header, ownPosts: _emptyPage);
      final vm = _vm(repo);
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(find.text('house'), findsOneWidget);
      expect(find.text('ambient'), findsOneWidget);
    });

    testWidgets('shows empty posts message when no posts', (tester) async {
      final repo = _StubRepo(ownProfile: _header, ownPosts: _emptyPage);
      final vm = _vm(repo);
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(find.text('No posts yet.'), findsOneWidget);
    });

    testWidgets('renders post items', (tester) async {
      final repo = _StubRepo(
        ownProfile: _header,
        ownPosts: () => ProfilePostsPage(
          items: [_post('p1'), _post('p2')],
          pageSize: 20,
          count: 2,
        ),
      );
      final vm = _vm(repo);
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    });
  });

  group('ProfileScreen — error state', () {
    testWidgets('shows header error with retry when header fails', (
      tester,
    ) async {
      final repo = _StubRepo(
        ownError: Exception('error'),
        ownPosts: _emptyPage,
      );
      final vm = _vm(repo);
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load profile. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsWidgets);
    });

    testWidgets('shows posts error while keeping header visible', (
      tester,
    ) async {
      final repo = _StubRepo(
        ownProfile: _header,
        postsError: Exception('posts error'),
      );
      final vm = _vm(repo);
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget); // header still visible
      expect(
        find.text('Could not load posts. Please try again.'),
        findsOneWidget,
      );
    });
  });

  group('ProfileScreen — not found state', () {
    testWidgets('shows not found message for missing profile', (tester) async {
      final repo = _StubRepo(
        ownError: const ProfileNotFoundException(),
        ownPosts: _emptyPage,
      );
      final vm = _vm(repo);
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(find.text('This profile could not be found.'), findsOneWidget);
    });
  });

  group('ProfileScreen — auth required state', () {
    testWidgets('shows auth error when session expired', (tester) async {
      final repo = _StubRepo(
        ownError: const ProfileAuthException(),
        ownPosts: _emptyPage,
      );
      final vm = _vm(repo);
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not load profile. Please try again.'),
        findsWidgets,
      );
    });
  });

  group('ProfileScreen — mode indicator title', () {
    testWidgets('shows myProfileTitle for own profile (no userId)', (
      tester,
    ) async {
      final repo = _StubRepo(ownProfile: _header, ownPosts: _emptyPage);
      final vm = _vm(repo, currentUserId: 'uid-1');
      await tester.pumpWidget(_wrap(ProfileScreen(viewModel: vm)));
      await tester.pumpAndSettle();

      expect(find.text('My Profile'), findsOneWidget);
    });

    testWidgets('shows userProfileTitle with username for other-user profile', (
      tester,
    ) async {
      final repo = _StubRepo(ownProfile: _header, ownPosts: _emptyPage);
      final vm = _vm(repo, currentUserId: 'other-user');
      await tester.pumpWidget(
        _wrap(ProfileScreen(viewModel: vm, userId: 'uid-1')),
      );
      await tester.pumpAndSettle();

      expect(find.text("alice's Profile"), findsOneWidget);
    });
  });

  group('ProfileScreen — dark/light mode', () {
    testWidgets('renders correctly in dark mode', (tester) async {
      final repo = _StubRepo(ownProfile: _header, ownPosts: _emptyPage);
      final vm = _vm(repo);
      await tester.pumpWidget(
        _wrap(ProfileScreen(viewModel: vm), theme: AppTheme.dark),
      );
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
    });
  });
}
