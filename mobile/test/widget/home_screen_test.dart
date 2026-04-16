import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/ui/home/home_screen.dart';
import 'package:mobile/ui/home/home_view_model.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_theme.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
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

Widget _buildTestRouterApp(GoRouter router) {
  return MaterialApp.router(
    routerConfig: router,
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

class _StubHomeViewModel extends HomeViewModel {
  _StubHomeViewModel(this._state, {this.stubPosts = const []});

  final HomeScreenState _state;
  final List<HomeFeedPost> stubPosts;

  @override
  HomeScreenState get state => _state;

  @override
  List<HomeFeedPost> get posts => stubPosts;
}

void main() {
  testWidgets('loading state renders CircularProgressIndicator', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        HomeScreen(viewModel: _StubHomeViewModel(HomeScreenState.loading)),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('empty state renders emptyMessage string', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        HomeScreen(viewModel: _StubHomeViewModel(HomeScreenState.empty)),
      ),
    );
    await tester.pump();
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('error state renders errorMessage and retry button', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        HomeScreen(viewModel: _StubHomeViewModel(HomeScreenState.error)),
      ),
    );
    await tester.pump();
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('data state renders homeTitle', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        HomeScreen(viewModel: _StubHomeViewModel(HomeScreenState.data)),
      ),
    );
    await tester.pump();
    expect(find.text('Feed'), findsOneWidget);
  });

  testWidgets('data state renders sample feed posts', (tester) async {
    final posts = [
      HomeFeedPost(
        id: 'post-1',
        userId: 'user-1',
        userName: 'Natalie Cooper',
        userHandle: '@nataliecooper',
        text: 'Loving the vibe of this track.',
        spotifyUrl: 'https://open.spotify.com/track/lostinthesound',
        createdAt: DateTime(2026, 4, 14),
      ),
    ];
    await tester.pumpWidget(
      _buildTestApp(
        HomeScreen(
          viewModel: _StubHomeViewModel(HomeScreenState.data, stubPosts: posts),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Natalie Cooper'), findsOneWidget);
    expect(find.text('Loving the vibe of this track.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Spotify'), findsWidgets);
  });

  testWidgets('tapping author name opens that user profile', (tester) async {
    final posts = [
      HomeFeedPost(
        id: 'post-1',
        userId: 'user-1',
        userName: 'Natalie Cooper',
        userHandle: '@nataliecooper',
        text: 'Loving the vibe of this track.',
        spotifyUrl: 'https://open.spotify.com/track/lostinthesound',
        createdAt: DateTime(2026, 4, 14),
      ),
    ];

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => HomeScreen(
            viewModel: _StubHomeViewModel(
              HomeScreenState.data,
              stubPosts: posts,
            ),
          ),
        ),
        GoRoute(
          path: '/profile/:userId',
          builder: (context, state) =>
              Text('profile:${state.pathParameters['userId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(_buildTestRouterApp(router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Natalie Cooper'));
    await tester.pumpAndSettle();

    expect(find.text('profile:user-1'), findsOneWidget);
  });
}
