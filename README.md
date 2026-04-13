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

## Service Docs
- Backend setup and auth verification API examples: `backend/README.md`
