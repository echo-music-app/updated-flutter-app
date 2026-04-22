import httpx

from backend.core.config import Settings
from backend.domain.auth.entities import SoundCloudIdentity
from backend.domain.auth.exceptions import InvalidSoundCloudTokenError, SoundCloudAuthNotConfiguredError

_SOUNDCLOUD_ME_URL = "https://api.soundcloud.com/me"


async def exchange_soundcloud_code_for_identity(
    settings: Settings,
    *,
    code: str,
    redirect_uri: str,
) -> SoundCloudIdentity:
    if not settings.soundcloud_client_id or not settings.soundcloud_client_secret.get_secret_value():
        raise SoundCloudAuthNotConfiguredError("SoundCloud authentication is not configured")

    timeout = httpx.Timeout(connect=5.0, read=10.0, write=5.0, pool=5.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        token_response = await client.post(
            settings.soundcloud_token_url,
            data={
                "grant_type": "authorization_code",
                "code": code,
                "redirect_uri": redirect_uri,
                "client_id": settings.soundcloud_client_id,
                "client_secret": settings.soundcloud_client_secret.get_secret_value(),
            },
        )
        if token_response.status_code != 200:
            raise InvalidSoundCloudTokenError("SoundCloud token exchange failed")

        token_payload = token_response.json()
        access_token = token_payload.get("access_token")
        if not access_token:
            raise InvalidSoundCloudTokenError("SoundCloud access token is missing")

        profile_response = await client.get(
            _SOUNDCLOUD_ME_URL,
            headers={"Authorization": f"OAuth {access_token}"},
        )
        if profile_response.status_code != 200:
            raise InvalidSoundCloudTokenError("Could not fetch SoundCloud profile")

    profile = profile_response.json()
    subject = profile.get("id")
    email = profile.get("email")
    if subject is None or not email:
        raise InvalidSoundCloudTokenError("SoundCloud account email is unavailable")

    name = profile.get("full_name") or profile.get("username")
    return SoundCloudIdentity(
        subject=str(subject),
        email=str(email).strip().lower(),
        name=str(name).strip() if isinstance(name, str) and name.strip() else None,
    )
