import uuid
from datetime import UTC, datetime, timedelta
import re

from backend.core.config import Settings
from backend.core.security import hash_password
from backend.domain.auth.entities import TokenPair
from backend.domain.auth.repositories import ITokenRepository
from backend.domain.spotify.entities import TrackResponse
from backend.domain.spotify.exceptions import SpotifyAuthError
from backend.domain.spotify.repositories import ISpotifyCredentialsRepository
from backend.infrastructure.persistence.models.user import UserStatus
from backend.infrastructure.spotify.client import SpotifyClient
from backend.domain.auth.repositories import IUserRepository


class SpotifyUseCases:
    def __init__(
        self,
        creds_repo: ISpotifyCredentialsRepository,
        token_repo: ITokenRepository,
        user_repo: IUserRepository,
        spotify_client: SpotifyClient,
        settings: Settings,
    ) -> None:
        self._creds_repo = creds_repo
        self._token_repo = token_repo
        self._user_repo = user_repo
        self._spotify_client = spotify_client
        self._settings = settings

    async def exchange_code(
        self,
        user_id: uuid.UUID | None,
        code: str,
        code_verifier: str,
        redirect_uri: str,
    ) -> TokenPair:
        from backend.infrastructure.spotify.client import encrypt_token

        token_data = await self._spotify_client.exchange_code(code, code_verifier, redirect_uri)
        profile = await self._spotify_client.get_user_profile(token_data["access_token"])
        spotify_user_id = profile.get("id")
        if not spotify_user_id:
            raise SpotifyAuthError("Spotify profile is missing user id")

        encrypted_access = encrypt_token(token_data["access_token"])
        encrypted_refresh = encrypt_token(token_data["refresh_token"])
        token_expiry = datetime.now(UTC) + timedelta(seconds=token_data["expires_in"])

        existing = await self._creds_repo.get_by_spotify_user_id(spotify_user_id)

        if existing:
            await self._creds_repo.upsert(
                spotify_user_id=spotify_user_id,
                user_id=user_id or existing.user_id,
                access_token=encrypted_access,
                refresh_token=encrypted_refresh,
                token_expiry=token_expiry,
                scope=token_data.get("scope", ""),
            )
            effective_user_id = user_id or existing.user_id
        else:
            if not user_id:
                email = (profile.get("email") or "").strip().lower()
                if not email:
                    raise SpotifyAuthError("Spotify account email is unavailable")
                user = await self._user_repo.get_by_email(email)
                if user is None:
                    username = await self._generate_available_username(
                        profile.get("display_name") or email.split("@", 1)[0],
                    )
                    user = await self._user_repo.create(
                        email,
                        username,
                        hash_password(str(uuid.uuid4())),
                    )
                    await self._user_repo.mark_email_verified(user.id, verified_at=datetime.now(UTC))
                if str(getattr(user, "status", "")) == str(UserStatus.disabled):
                    raise SpotifyAuthError("Account is disabled")
                user_id = user.id
            await self._creds_repo.upsert(
                spotify_user_id=spotify_user_id,
                user_id=user_id,
                access_token=encrypted_access,
                refresh_token=encrypted_refresh,
                token_expiry=token_expiry,
                scope=token_data.get("scope", ""),
            )
            effective_user_id = user_id

        return await self._issue_echo_tokens(effective_user_id)

    async def refresh_token(self, echo_refresh_token: str) -> TokenPair:
        from backend.core.security import hash_token
        from backend.infrastructure.spotify.client import encrypt_token

        now = datetime.now(UTC)
        token_hash = hash_token(echo_refresh_token)
        old_refresh = await self._token_repo.get_refresh_by_hash(token_hash)

        if old_refresh is None or old_refresh.expires_at < now or old_refresh.rotated_at or old_refresh.revoked_at:
            raise SpotifyAuthError("Invalid or expired refresh token")

        cred = await self._creds_repo.get_by_user_id(old_refresh.user_id)
        if cred and cred.token_expiry - now < timedelta(seconds=60):
            try:
                new_token_data = await self._spotify_client.refresh_token(cred.refresh_token)
                new_encrypted_access = encrypt_token(new_token_data["access_token"])
                new_encrypted_refresh = encrypt_token(new_token_data["refresh_token"]) if "refresh_token" in new_token_data else None
                new_expiry = datetime.now(UTC) + timedelta(seconds=new_token_data["expires_in"])
                await self._creds_repo.update_tokens(cred.id, new_encrypted_access, new_encrypted_refresh, new_expiry)
            except SpotifyAuthError:
                await self._creds_repo.delete(cred.id)
                raise

        await self._token_repo.rotate_refresh(old_refresh.id, now)
        if old_refresh.access_token_id:
            await self._token_repo.revoke_access(old_refresh.access_token_id, now)

        return await self._issue_echo_tokens(old_refresh.user_id)

    async def get_track(self, user_id: uuid.UUID, track_id: str) -> TrackResponse:
        from backend.infrastructure.spotify.client import decrypt_token

        cred = await self._creds_repo.get_by_user_id(user_id)
        if not cred:
            from backend.domain.spotify.exceptions import SpotifyApiError

            raise SpotifyApiError(401, "No Spotify credentials found")

        spotify_access_token = decrypt_token(cred.access_token)
        return await self._spotify_client.get_track(spotify_access_token, track_id)

    async def _issue_echo_tokens(self, user_id: uuid.UUID) -> TokenPair:
        from backend.core.security import generate_token

        now = datetime.now(UTC)
        access_raw, access_hash = generate_token()
        refresh_raw, refresh_hash = generate_token()

        access_token = await self._token_repo.create_access_token(
            user_id=user_id,
            token_hash=access_hash,
            expires_at=now + timedelta(seconds=self._settings.access_token_ttl_seconds),
        )
        await self._token_repo.create_refresh_token(
            user_id=user_id,
            token_hash=refresh_hash,
            access_token_id=access_token.id,
            expires_at=now + timedelta(days=self._settings.refresh_token_ttl_days),
        )

        return TokenPair(
            access_token=access_raw,
            refresh_token=refresh_raw,
            expires_in=self._settings.access_token_ttl_seconds,
        )

    async def _generate_available_username(self, seed: str) -> str:
        base = re.sub(r"[^a-zA-Z0-9_.-]+", "", seed.lower()) or "spotify-user"
        base = base[:50]
        candidate = base
        suffix = 1
        while await self._user_repo.get_by_username(candidate) is not None:
            suffix_text = str(suffix)
            trimmed_base = base[: max(1, 50 - len(suffix_text) - 1)]
            candidate = f"{trimmed_base}-{suffix_text}"
            suffix += 1
        return candidate
