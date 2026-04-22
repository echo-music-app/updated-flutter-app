# Mobile App

## Local Run
1. `flutter pub get`
2. `flutter run --dart-define=ECHO_BASE_URL=http://10.0.2.2:8001`

## Spotify Login
This app supports Spotify login/signup through backend `POST /v1/auth/spotify/token`.

Run with:

```bash
flutter run \
  --dart-define=ECHO_BASE_URL=http://10.0.2.2:8001 \
  --dart-define=SPOTIFY_CLIENT_ID=<spotify-client-id> \
  --dart-define=SPOTIFY_REDIRECT_URI=<your-app-redirect-uri>
```

Optional:
- `--dart-define=APPLE_CLIENT_ID=<apple-service-id>`
- `--dart-define=APPLE_REDIRECT_URI=<apple-redirect-uri>`

Notes:
- `SPOTIFY_REDIRECT_URI` must match the redirect URI configured in your Spotify app.
- Backend must be configured with `SPOTIFY_CLIENT_ID` and `SPOTIFY_CLIENT_SECRET`.
