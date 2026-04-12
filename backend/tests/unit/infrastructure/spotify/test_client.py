"""Unit tests for infrastructure/spotify/client.py — AES-256-GCM helpers."""

import pytest

from backend.infrastructure.spotify.client import decrypt_token, encrypt_token


@pytest.fixture(autouse=True)
def _set_encryption_key(monkeypatch):
    """Provide a test AES-256-GCM key (32 bytes = 64 hex chars)."""
    test_key = "ab" * 32  # 64 hex chars = 32 bytes
    monkeypatch.setenv("SPOTIFY_TOKEN_ENCRYPTION_KEY", test_key)
    from backend.core.config import get_settings

    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


# ---------------------------------------------------------------------------
# encrypt_token / decrypt_token
# ---------------------------------------------------------------------------


class TestEncryptDecryptRoundTrip:
    def test_round_trip_access_token(self):
        original = "BQDn5Gs-spotify-access-token-example"
        encrypted = encrypt_token(original)
        assert decrypt_token(encrypted) == original

    def test_round_trip_refresh_token(self):
        original = "AQDQl2Z-spotify-refresh-token-example-longer-value"
        assert decrypt_token(encrypt_token(original)) == original

    def test_round_trip_empty_string(self):
        assert decrypt_token(encrypt_token("")) == ""


class TestVersionedEnvelope:
    def test_version_byte_is_one(self):
        encrypted = encrypt_token("test-token")
        assert encrypted[0] == 1

    def test_wrong_version_raises(self):
        encrypted = encrypt_token("test-token")
        corrupted = bytes([99]) + encrypted[1:]
        with pytest.raises(ValueError, match="Unsupported key version"):
            decrypt_token(corrupted)

    def test_different_nonces_per_call(self):
        token = "same-token-value"
        enc1 = encrypt_token(token)
        enc2 = encrypt_token(token)
        assert enc1 != enc2

    def test_ciphertext_is_bytes(self):
        assert isinstance(encrypt_token("any-token"), bytes)

    def test_minimum_ciphertext_length(self):
        """1 (version) + 12 (nonce) + 16 (GCM tag) = 29 bytes minimum."""
        assert len(encrypt_token("")) >= 29


class TestCorruptionDetection:
    def test_corrupted_ciphertext_raises(self):
        encrypted = encrypt_token("sensitive-token")
        corrupted = encrypted[:-5] + b"\x00\x00\x00\x00\x00"
        with pytest.raises(Exception):
            decrypt_token(corrupted)

    def test_truncated_data_raises(self):
        with pytest.raises(Exception):
            decrypt_token(b"\x01" + b"\x00" * 5)
