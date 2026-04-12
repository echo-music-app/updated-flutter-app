// T064: Widget test for WebViewLimitationBanner — renders ARB string, no raw key fallback.
// Must FAIL before T066 implementation.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/player_webview/widgets/webview_limitation_banner.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('WebViewLimitationBanner', () {
    testWidgets('renders the webViewLimitationNotice ARB string', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WebViewLimitationBanner()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Audio playback is not available'),
        findsOneWidget,
      );
    });

    testWidgets('does not render a raw key fallback string', (tester) async {
      await tester.pumpWidget(_wrap(const WebViewLimitationBanner()));
      await tester.pumpAndSettle();

      expect(find.text('webViewLimitationNotice'), findsNothing);
    });

    testWidgets('has no dismiss action (is a persistent notice)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const WebViewLimitationBanner()));
      await tester.pumpAndSettle();

      // No close/dismiss button present
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}
