// T026: SpotifyLoginScreen — pre-auth state shows "Connect with Spotify";
// post-auth state shows navigation handled by GoRouter redirect.
// All strings from ARB (constitution Principle VII).
import 'package:flutter/material.dart';
import 'package:mobile/ui/login/login_view_model.dart';
import 'package:mobile/generated/l10n/app_localizations.dart';
import 'package:mobile/ui/core/themes/app_spacing.dart';

class SpotifyLoginScreen extends StatelessWidget {
  const SpotifyLoginScreen({super.key, required this.viewModel});

  final LoginViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            if (viewModel.isLoading) {
              return const CircularProgressIndicator();
            }
            return Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image(
                    image: const AssetImage('assets/images/logo_light.png'),
                    height: 120,
                  ),
                  SizedBox(height: AppSpacing.xl),
                  Semantics(
                    label: l10n.connectWithSpotify,
                    child: ElevatedButton(
                      onPressed: viewModel.connectWithSpotify,
                      child: Text(l10n.connectWithSpotify),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
