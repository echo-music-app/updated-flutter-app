import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile_view/domain/entities/profile_posts_page.dart';
import 'package:mobile/features/profile_view/presentation/widgets/profile_posts_list.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_theme.dart';

Widget _wrap(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.light,
  darkTheme: AppTheme.dark,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

ProfilePostSummary _post(String id) => ProfilePostSummary(
  id: id,
  userId: 'u',
  privacy: 'Public',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

Future<List<ProfilePostComment>> _viewComments(String postId) async => const [];

Future<ProfilePostComment?> _addComment(String postId, String content) async =>
    null;
void main() {
  group('ProfilePostsList â€” empty state', () {
    testWidgets('shows empty message when no posts', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: const [],
            canLoadMore: false,
            isLoadingMore: false,
            onLoadMore: () {},
            onRetryLoadMore: () {},
            onViewComments: _viewComments,
            onAddComment: _addComment,
          ),
        ),
      );
      expect(find.text('No posts yet.'), findsOneWidget);
    });
  });

  group('ProfilePostsList â€” data state', () {
    testWidgets('renders post items', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: [_post('p1'), _post('p2')],
            canLoadMore: false,
            isLoadingMore: false,
            onLoadMore: () {},
            onRetryLoadMore: () {},
            onViewComments: _viewComments,
            onAddComment: _addComment,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    });
  });

  group('ProfilePostsList â€” load-more', () {
    testWidgets('shows load more button when canLoadMore is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: [_post('p1')],
            canLoadMore: true,
            isLoadingMore: false,
            onLoadMore: () {},
            onRetryLoadMore: () {},
            onViewComments: _viewComments,
            onAddComment: _addComment,
          ),
        ),
      );
      expect(find.text('Load more posts'), findsOneWidget);
    });

    testWidgets('load-more button triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: [_post('p1')],
            canLoadMore: true,
            isLoadingMore: false,
            onLoadMore: () => tapped = true,
            onRetryLoadMore: () {},
            onViewComments: _viewComments,
            onAddComment: _addComment,
          ),
        ),
      );
      await tester.tap(find.text('Load more posts'));
      expect(tapped, true);
    });

    testWidgets('shows loading indicator while loading more', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: [_post('p1')],
            canLoadMore: false,
            isLoadingMore: true,
            onLoadMore: () {},
            onRetryLoadMore: () {},
            onViewComments: _viewComments,
            onAddComment: _addComment,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows retry button on load-more error', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: [_post('p1')],
            canLoadMore: false,
            isLoadingMore: false,
            onLoadMore: () {},
            onRetryLoadMore: () => retried = true,
            onViewComments: _viewComments,
            onAddComment: _addComment,
            hasLoadMoreError: true,
          ),
        ),
      );
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, true);
    });

    testWidgets('appends without replacing items after load-more', (
      tester,
    ) async {
      final posts = [_post('p1')];

      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: posts,
            canLoadMore: false,
            isLoadingMore: false,
            onLoadMore: () {},
            onRetryLoadMore: () {},
            onViewComments: _viewComments,
            onAddComment: _addComment,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('p1')), findsOneWidget);

      final updated = [...posts, _post('p2')];
      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: updated,
            canLoadMore: false,
            isLoadingMore: false,
            onLoadMore: () {},
            onRetryLoadMore: () {},
            onViewComments: _viewComments,
            onAddComment: _addComment,
          ),
        ),
      );
      expect(find.byKey(const ValueKey('p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('p2')), findsOneWidget);
    });
  });

  group('ProfilePostsList â€” dark mode', () {
    testWidgets('renders correctly in dark theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ProfilePostsList(
            posts: [_post('p1')],
            canLoadMore: false,
            isLoadingMore: false,
            onLoadMore: () {},
            onRetryLoadMore: () {},
            onViewComments: _viewComments,
            onAddComment: _addComment,
          ),
          theme: AppTheme.dark,
        ),
      );
      expect(find.byKey(const ValueKey('p1')), findsOneWidget);
    });
  });
}
