# Mobile App

## Local Run
1. `flutter pub get`
2. `flutter run --dart-define=ECHO_BASE_URL=http://10.0.2.2:8001`

## Google Sign-In
This app supports Google login/signup through backend `POST /v1/auth/google`.

Run with:

```bash
flutter run \
  --dart-define=ECHO_BASE_URL=http://10.0.2.2:8001 \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=<your-web-client-id>.apps.googleusercontent.com
```

Optional:
- `--dart-define=GOOGLE_CLIENT_ID=<client-id>`

Notes:
- On Android, `GOOGLE_SERVER_CLIENT_ID` is required.
- Backend must include the same Web client ID in `GOOGLE_CLIENT_IDS`.
