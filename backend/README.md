# Backend Service

## Local Setup
1. `cd backend`
2. `uv sync --locked --dev`
3. Ensure `backend/.env` exists (copy from `.env.example`).
4. Start Postgres: `docker compose -f ..\\compose.yml up -d postgres`
5. Run migrations: `uv run alembic upgrade head`
6. Start API: `uv run uvicorn backend.main:app --reload --host 0.0.0.0 --port 8001`

## Auth + Email Verification
1. For local testing without SMTP, set `DEBUG=true` in `backend/.env`.
2. Register creates a pending account and issues a verification code.
3. Verify email to receive `access_token` and `refresh_token`.
4. Login is blocked until email is verified.

### Register (no tokens yet)
```bash
curl -X POST http://127.0.0.1:8001/v1/auth/register \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"alice@example.com\",\"username\":\"alice\",\"password\":\"S3cur3P@ss!\"}"
```

### Verify Email (issues tokens)
```bash
curl -X POST http://127.0.0.1:8001/v1/auth/verify-email \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"alice@example.com\",\"code\":\"123456\"}"
```

### Login (only after verification)
```bash
curl -X POST http://127.0.0.1:8001/v1/auth/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=alice@example.com&password=S3cur3P@ss!&grant_type=password"
```

### Resend Verification Code
```bash
curl -X POST http://127.0.0.1:8001/v1/auth/resend-verification \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"alice@example.com\"}"
```

## Google Authentication
1. Add your Google Web client ID to `backend/.env`:
   - `GOOGLE_CLIENT_IDS=your-web-client-id.apps.googleusercontent.com`
2. Mobile sends Google `id_token` to:
   - `POST /v1/auth/google`
3. Backend verifies:
   - token signature/issuer
   - audience against `GOOGLE_CLIENT_IDS`

## Two-Factor Authentication (TOTP)
1. Run latest migration:
   - `uv run alembic upgrade head`
2. Login to get bearer token.
3. Start MFA setup:
   - `POST /v1/auth/mfa/setup` with `Authorization: Bearer <access_token>`
4. Scan `otpauth_uri` in authenticator app (Google Authenticator/Authy/1Password).
5. Enable MFA:
   - `POST /v1/auth/mfa/enable` body: `{"code":"123456"}`
6. Next logins require header:
   - `X-MFA-Code: 123456`
