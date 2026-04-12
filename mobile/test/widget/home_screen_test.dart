import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _StubHomeViewModel extends HomeViewModel {
  _StubHomeViewModel(this._state);

  final HomeScreenState _state;

  @override
  HomeScreenState get state => _state;
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
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('data state renders Search Music navigation entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        HomeScreen(viewModel: _StubHomeViewModel(HomeScreenState.data)),
      ),
    );
    await tester.pump();
    expect(find.widgetWithText(ElevatedButton, 'Search Music'), findsOneWidget);
  });
}
