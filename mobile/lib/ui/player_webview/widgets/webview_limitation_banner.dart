// T066: WebViewLimitationBanner — persistent informational notice explaining
// that audio playback is unavailable in the WebView player due to Widevine EME
// constraints (FR-025). Always visible in the data state; no dismiss action.
import 'package:flutter/material.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';

class WebViewLimitationBanner extends StatelessWidget {
  const WebViewLimitationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.sm),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              l10n.webViewLimitationNotice,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
