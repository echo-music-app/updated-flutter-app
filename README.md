# Echo Monorepo

## Backend (Local)
1. `cd backend`
2. `uv sync --locked --dev`
3. Start Postgres: `docker compose -f ..\\compose.yml up -d postgres`
4. Run migrations: `uv run alembic upgrade head`
5. Start API: `uv run uvicorn backend.main:app --reload --host 0.0.0.0 --port 8001`
6. Open docs: `http://127.0.0.1:8001/docs`

## Mobile (Android Emulator)
1. `cd mobile`
2. `flutter pub get`
3. `flutter run --dart-define=ECHO_BASE_URL=http://10.0.2.2:8001`

## Mobile (Physical Android Device)
1. Ensure phone and laptop are on the same Wi-Fi.
2. Find your laptop IPv4 address (for example `192.168.1.50`).
3. Start backend with host `0.0.0.0` (already shown above).
4. Run:
   - `flutter run --dart-define=ECHO_BASE_URL=http://<your-ip>:8001`
5. If request fails, allow Python/Uvicorn through Windows Firewall.

### Google Sign-In (Android)
1. Create OAuth clients in Google Cloud:
   - Android client (`com.echo.app` + SHA-1)
   - Web client (used as server client ID)
2. Set backend allowlist in `backend/.env`:
   - `GOOGLE_CLIENT_IDS=<your-web-client-id>.apps.googleusercontent.com`
3. Run mobile with server client ID:
   - `flutter run --dart-define=ECHO_BASE_URL=http://10.0.2.2:8001 --dart-define=GOOGLE_SERVER_CLIENT_ID=<your-web-client-id>.apps.googleusercontent.com`

## Auth Flow Added
- Email registration now requires verification code.
- Password policy + strength indicator shown on register.
- Resend/verify email flow is available in-app.
- Google sign-in endpoint is wired (`/v1/auth/google`) for deployment setup.

## Real Post Flow (Backend Connected)
- Create post screen publishes to backend (`POST /v1/posts`).
- Post privacy is supported: `Public`, `Friends`, `OnlyMe`.
- Optional post content fields:
  - `text`
  - `spotify_url`
- Profile posts and home feed now load from backend APIs:
  - `GET /v1/me/posts`
  - `GET /v1/user/{userId}/posts`
  - `GET /v1/posts`
- Posts are persisted in database, so they remain after app restart.

## Quick Verification Checklist
1. Login in mobile app.
2. Create a post (text and/or Spotify URL, choose privacy).
3. Open profile and confirm the new post is visible.
4. Restart app and login again.
5. Confirm the post is still visible in profile/feed.

## Common Local Issues
- `Could not load profile. Please try again.`:
  - Backend is not running or `ECHO_BASE_URL` is wrong.
- Emulator cannot connect:
  - Use `http://10.0.2.2:8001`, not `localhost`.
- Physical device cannot connect:
  - Use `http://<your-ip>:8001` and check firewall.
- Alembic connection errors (`getaddrinfo failed`, `ConnectionRefusedError`):
  - Ensure Postgres container is up and `backend/.env` DB host/port are correct.

## Service Docs
- Backend setup and auth verification API examples: `backend/README.md`
