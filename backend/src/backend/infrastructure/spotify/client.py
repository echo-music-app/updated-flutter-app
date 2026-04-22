import os
import struct

import httpx
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from backend.core.config import get_settings
from backend.domain.spotify.entities import TrackResponse
from backend.domain.spotify.exceptions import SpotifyApiError, SpotifyAuthError

# Versioned envelope: 1 byte version prefix + 12 byte nonce + ciphertext + 16 byte tag
_KEY_VERSION = 1
_NONCE_LENGTH = 12

SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
SPOTIFY_USER_URL = "https://api.spotify.com/v1/me"
SPOTIFY_TRACK_URL = "https://api.spotify.com/v1/tracks"


def _get_encryption_key() -> bytes:
    settings = get_settings()
    raw = settings.spotify_token_encryption_key.get_secret_value()
    return bytes.fromhex(raw)


def encrypt_token(plaintext: str) -> bytes:
    """Encrypt a token string using AES-256-GCM with versioned envelope."""
    key = _get_encryption_key()
    nonce = os.urandom(_NONCE_LENGTH)
    aesgcm = AESGCM(key)
    ciphertext = aesgcm.encrypt(nonce, plaintext.encode("utf-8"), None)
    return struct.pack("B", _KEY_VERSION) + nonce + ciphertext


def decrypt_token(data: bytes) -> str:
    """Decrypt a versioned AES-256-GCM envelope back to a token string."""
    key = _get_encryption_key()
    version = struct.unpack("B", data[:1])[0]
    if version != _KEY_VERSION:
        raise ValueError(f"Unsupported key version: {version}")
    nonce = data[1 : 1 + _NONCE_LENGTH]
    ciphertext = data[1 + _NONCE_LENGTH :]
    aesgcm = AESGCM(key)
    return aesgcm.decrypt(nonce, ciphertext, None).decode("utf-8")


class SpotifyClient:
    def __init__(self) -> None:
        self._settings = get_settings()
        self._timeout = httpx.Timeout(connect=5.0, read=10.0, write=5.0, pool=5.0)

    async def exchange_code(self, code: str, code_verifier: str, redirect_uri: str) -> dict:
        """Exchange authorization code for Spotify tokens. Returns token data dict."""
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            resp = await client.post(
                SPOTIFY_TOKEN_URL,
                data={
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirect_uri,
                    "client_id": self._settings.spotify_client_id,
                    "client_secret": self._settings.spotify_client_secret.get_secret_value(),
                    "code_verifier": code_verifier,
                },
            )
        if resp.status_code != 200:
            raise SpotifyAuthError(f"Spotify token exchange failed: {resp.status_code}")
        return resp.json()

    async def get_user_profile(self, access_token: str) -> dict:
        """Fetch Spotify user profile and return basic identity fields."""
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            resp = await client.get(
                SPOTIFY_USER_URL,
                headers={"Authorization": f"Bearer {access_token}"},
            )
        if resp.status_code != 200:
            raise SpotifyAuthError(f"Failed to fetch Spotify user profile: {resp.status_code}")
        data = resp.json()
        return {
            "id": data.get("id"),
            "email": data.get("email"),
            "display_name": data.get("display_name"),
        }

    async def refresh_token(self, encrypted_refresh_token: bytes) -> dict:
        """Refresh Spotify access token using the stored (encrypted) refresh token. Returns token data dict."""
        spotify_refresh = decrypt_token(encrypted_refresh_token)
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            resp = await client.post(
                SPOTIFY_TOKEN_URL,
                data={
                    "grant_type": "refresh_token",
                    "refresh_token": spotify_refresh,
                    "client_id": self._settings.spotify_client_id,
                    "client_secret": self._settings.spotify_client_secret.get_secret_value(),
                },
            )
        if resp.status_code == 401:
            raise SpotifyAuthError("Spotify refresh token revoked")
        if resp.status_code != 200:
            raise SpotifyAuthError(f"Spotify token refresh failed: {resp.status_code}")
        return resp.json()

    async def get_track(self, access_token: str, track_id: str) -> TrackResponse:
        """Fetch track metadata from Spotify Web API."""
        async with httpx.AsyncClient(timeout=self._timeout) as client:
            resp = await client.get(
                f"{SPOTIFY_TRACK_URL}/{track_id}",
                headers={"Authorization": f"Bearer {access_token}"},
            )

        if resp.status_code == 401:
            raise SpotifyApiError(401, "Spotify access token expired")
        if resp.status_code == 404:
            raise SpotifyApiError(404, "Track not found")
        if resp.status_code == 429:
            raise SpotifyApiError(503, "Spotify rate limited")
        if resp.status_code != 200:
            raise SpotifyApiError(503, f"Spotify API error: {resp.status_code}")

        data = resp.json()
        artists = data.get("artists", [])
        artist_name = artists[0]["name"] if artists else "Unknown Artist"
        images = data.get("album", {}).get("images", [])
        album_art_url = images[0]["url"] if images else ""

        return TrackResponse(
            id=data["id"],
            uri=data["uri"],
            name=data["name"],
            artist_name=artist_name,
            album_art_url=album_art_url,
            duration_ms=data["duration_ms"],
        )
