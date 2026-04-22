"""Integration tests for /v1/auth endpoints."""

from datetime import UTC, datetime, timedelta

import pytest
import uuid6
from httpx import AsyncClient
from sqlalchemy import select, text
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.security import generate_token, hash_password, hash_token
from backend.domain.auth.entities import AppleIdentity, SoundCloudIdentity
from backend.domain.auth.exceptions import InvalidAppleTokenError, InvalidSoundCloudTokenError
from backend.infrastructure.persistence.models.auth import AccessToken, RefreshToken
from backend.infrastructure.persistence.models.user import User, UserStatus


async def _register(client: AsyncClient, email: str, username: str, password: str = "S3cur3P@ss!") -> dict:
    response = await client.post(
        "/v1/auth/register",
        json={"email": email, "username": username, "password": password},
    )
    assert response.status_code == 201
    return response.json()


async def _register_and_verify(
    client: AsyncClient,
    email: str,
    username: str,
    password: str = "S3cur3P@ss!",
) -> tuple[str, str]:
    reg = await _register(client, email, username, password=password)
    verify = await client.post(
        "/v1/auth/verify-email",
        json={"email": email, "code": reg["verification_code"]},
    )
    assert verify.status_code == 200
    payload = verify.json()
    return payload["access_token"], payload["refresh_token"]


@pytest.mark.anyio
async def test_register_success_returns_pending_verification(async_client: AsyncClient):
    body = await _register(async_client, "alice@example.com", "alice")
    assert body["verification_required"] is True
    assert isinstance(body["verification_expires_in"], int)
    assert body["verification_expires_in"] > 0
    assert isinstance(body["verification_code"], str)
    assert len(body["verification_code"]) == 6
    assert "access_token" not in body


@pytest.mark.anyio
async def test_register_invalid_email(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post(
        "/v1/auth/register",
        json={"email": "not-an-email", "username": "alice", "password": "S3cur3P@ss!"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_register_short_password(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post(
        "/v1/auth/register",
        json={"email": "a@b.com", "username": "alice", "password": "short"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
@pytest.mark.parametrize(
    "password",
    [
        "lowercase1!",
        "UPPERCASE1!",
        "NoNumber!",
        "NoSpecial1",
    ],
)
async def test_register_password_policy_requires_complexity(async_client_no_db: AsyncClient, password: str):
    response = await async_client_no_db.post(
        "/v1/auth/register",
        json={"email": "a@b.com", "username": "alice", "password": password},
    )
    assert response.status_code == 422
    assert "include uppercase, lowercase, number, and special character" in response.text


@pytest.mark.anyio
async def test_register_duplicate_email(async_client: AsyncClient):
    await _register(async_client, "dup@example.com", "user1")
    response = await async_client.post(
        "/v1/auth/register",
        json={"email": "dup@example.com", "username": "user2", "password": "S3cur3P@ss!"},
    )
    assert response.status_code == 409


@pytest.mark.anyio
async def test_register_duplicate_username(async_client: AsyncClient):
    await _register(async_client, "one@example.com", "dupuser")
    response = await async_client.post(
        "/v1/auth/register",
        json={"email": "two@example.com", "username": "dupuser", "password": "S3cur3P@ss!"},
    )
    assert response.status_code == 409


@pytest.mark.anyio
async def test_register_does_not_issue_tokens_before_verification(async_client: AsyncClient, db_session: AsyncSession):
    await _register(async_client, "pending@example.com", "pendinguser")

    access_tokens = (await db_session.execute(select(AccessToken))).scalars().all()
    refresh_tokens = (await db_session.execute(select(RefreshToken))).scalars().all()
    assert access_tokens == []
    assert refresh_tokens == []


@pytest.mark.anyio
async def test_verify_email_success_issues_tokens(async_client: AsyncClient, db_session: AsyncSession):
    reg = await _register(async_client, "verify@example.com", "verifyuser")

    verify = await async_client.post(
        "/v1/auth/verify-email",
        json={"email": "verify@example.com", "code": reg["verification_code"]},
    )
    assert verify.status_code == 200
    body = verify.json()
    assert "access_token" in body
    assert "refresh_token" in body
    assert body["token_type"] == "bearer"

    assert (await db_session.execute(select(AccessToken))).scalars().all()
    assert (await db_session.execute(select(RefreshToken))).scalars().all()


@pytest.mark.anyio
async def test_verify_email_invalid_code(async_client: AsyncClient):
    await _register(async_client, "badcode@example.com", "badcode")
    response = await async_client.post(
        "/v1/auth/verify-email",
        json={"email": "badcode@example.com", "code": "000000"},
    )
    assert response.status_code == 400


@pytest.mark.anyio
async def test_login_rejects_unverified_email(async_client: AsyncClient):
    await _register(async_client, "login_pending@example.com", "loginpending")

    response = await async_client.post(
        "/v1/auth/login",
        data={"username": "login_pending@example.com", "password": "S3cur3P@ss!", "grant_type": "password"},
    )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_login_success_after_verification(async_client: AsyncClient):
    await _register_and_verify(async_client, "login@example.com", "loginuser")

    response = await async_client.post(
        "/v1/auth/login",
        data={"username": "login@example.com", "password": "S3cur3P@ss!", "grant_type": "password"},
    )
    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert "refresh_token" in body


@pytest.mark.anyio
async def test_login_wrong_password(async_client: AsyncClient):
    await _register_and_verify(async_client, "wrongpw@example.com", "wrongpw")

    response = await async_client.post(
        "/v1/auth/login",
        data={"username": "wrongpw@example.com", "password": "wrongpassword", "grant_type": "password"},
    )
    assert response.status_code == 401


@pytest.mark.anyio
async def test_login_unknown_email(async_client: AsyncClient):
    response = await async_client.post(
        "/v1/auth/login",
        data={"username": "nobody@example.com", "password": "S3cur3P@ss!", "grant_type": "password"},
    )
    assert response.status_code == 401


@pytest.mark.anyio
async def test_login_disabled_account(async_client: AsyncClient, db_session: AsyncSession):
    await _register_and_verify(async_client, "disabled@example.com", "disableduser")
    result = await db_session.execute(select(User).where(User.email == "disabled@example.com"))
    result.scalar_one().status = UserStatus.disabled
    await db_session.flush()

    response = await async_client.post(
        "/v1/auth/login",
        data={"username": "disabled@example.com", "password": "S3cur3P@ss!", "grant_type": "password"},
    )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_refresh_token_success(async_client: AsyncClient):
    _, refresh_token = await _register_and_verify(async_client, "refresh@example.com", "refreshuser")

    response = await async_client.post("/v1/auth/refresh-token", json={"refresh_token": refresh_token})
    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert "refresh_token" in body


@pytest.mark.anyio
async def test_refresh_token_invalid(async_client: AsyncClient):
    response = await async_client.post("/v1/auth/refresh-token", json={"refresh_token": "not-a-real-token"})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_refresh_token_already_rotated(async_client: AsyncClient):
    _, refresh_token = await _register_and_verify(async_client, "rotated@example.com", "rotateduser")
    await async_client.post("/v1/auth/refresh-token", json={"refresh_token": refresh_token})

    response = await async_client.post("/v1/auth/refresh-token", json={"refresh_token": refresh_token})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_refresh_rotates_tokens_in_db(async_client: AsyncClient, db_session: AsyncSession):
    _, old_refresh_raw = await _register_and_verify(async_client, "rot_integ@example.com", "rotinteg")

    resp = await async_client.post("/v1/auth/refresh-token", json={"refresh_token": old_refresh_raw})
    assert resp.status_code == 200

    old_hash = hash_token(old_refresh_raw)
    old_refresh = (await db_session.execute(select(RefreshToken).where(RefreshToken.token_hash == old_hash))).scalar_one()
    assert old_refresh.rotated_at is not None


@pytest.mark.anyio
async def test_refresh_expired_token(async_client: AsyncClient, db_session: AsyncSession):
    user = User(
        id=uuid6.uuid7(),
        email="expired@example.com",
        username="expireduser",
        password_hash=hash_password("S3cur3P@ss!"),
        status=UserStatus.pending,
    )
    db_session.add(user)
    await db_session.flush()

    _, access_hash = generate_token()
    db_session.add(
        AccessToken(id=uuid6.uuid7(), token_hash=access_hash, user_id=user.id, expires_at=datetime.now(UTC) + timedelta(seconds=900))
    )

    refresh_raw, refresh_hash = generate_token()
    access = (await db_session.execute(select(AccessToken).where(AccessToken.token_hash == access_hash))).scalar_one()
    db_session.add(
        RefreshToken(
            id=uuid6.uuid7(),
            token_hash=refresh_hash,
            user_id=user.id,
            access_token_id=access.id,
            expires_at=datetime.now(UTC) - timedelta(days=1),
        )
    )
    await db_session.flush()

    response = await async_client.post("/v1/auth/refresh-token", json={"refresh_token": refresh_raw})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_logout_success(async_client: AsyncClient):
    access_token, _ = await _register_and_verify(async_client, "logout@example.com", "logoutuser")

    response = await async_client.post("/v1/auth/logout", headers={"Authorization": f"Bearer {access_token}"})
    assert response.status_code == 204


@pytest.mark.anyio
async def test_logout_no_auth(async_client: AsyncClient):
    response = await async_client.post("/v1/auth/logout")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_logout_revoked_token(async_client: AsyncClient):
    access_token, _ = await _register_and_verify(async_client, "rev@example.com", "revuser")
    await async_client.post("/v1/auth/logout", headers={"Authorization": f"Bearer {access_token}"})

    response = await async_client.post("/v1/auth/logout", headers={"Authorization": f"Bearer {access_token}"})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_logout_revokes_tokens_in_db(async_client: AsyncClient, db_session: AsyncSession):
    access_token, _ = await _register_and_verify(async_client, "lo_integ@example.com", "lointeg")

    resp = await async_client.post("/v1/auth/logout", headers={"Authorization": f"Bearer {access_token}"})
    assert resp.status_code == 204

    access_hash = hash_token(access_token)
    token = (await db_session.execute(select(AccessToken).where(AccessToken.token_hash == access_hash))).scalar_one()
    assert token.revoked_at is not None


@pytest.mark.anyio
async def test_auth_with_disabled_user(async_client: AsyncClient, db_session: AsyncSession):
    user = User(
        id=uuid6.uuid7(),
        email="dis_dep@example.com",
        username="disdep",
        password_hash=hash_password("S3cur3P@ss!"),
        status=UserStatus.disabled,
    )
    db_session.add(user)
    await db_session.flush()

    raw, token_hash = generate_token()
    db_session.add(
        AccessToken(id=uuid6.uuid7(), token_hash=token_hash, user_id=user.id, expires_at=datetime.now(UTC) + timedelta(seconds=900))
    )
    await db_session.flush()

    response = await async_client.post("/v1/auth/logout", headers={"Authorization": f"Bearer {raw}"})
    assert response.status_code == 403


@pytest.mark.anyio
async def test_auth_with_deleted_user(async_client: AsyncClient, db_session: AsyncSession):
    user = User(
        id=uuid6.uuid7(),
        email="todelete@example.com",
        username="todelete",
        password_hash=hash_password("S3cur3P@ss!"),
        status=UserStatus.pending,
    )
    db_session.add(user)
    await db_session.flush()

    raw, token_hash = generate_token()
    db_session.add(
        AccessToken(id=uuid6.uuid7(), token_hash=token_hash, user_id=user.id, expires_at=datetime.now(UTC) + timedelta(seconds=900))
    )
    await db_session.flush()

    await db_session.execute(text("SET session_replication_role = 'replica'"))
    await db_session.execute(text("DELETE FROM users WHERE id = :uid"), {"uid": user.id})
    await db_session.execute(text("SET session_replication_role = 'origin'"))
    await db_session.flush()

    response = await async_client.post("/v1/auth/logout", headers={"Authorization": f"Bearer {raw}"})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_refresh_token_not_found_returns_401(async_client: AsyncClient):
    response = await async_client.post("/v1/auth/refresh-token", json={"refresh_token": "completely_invalid_token_xyz"})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_apple_login_success_creates_or_links_user(
    async_client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
):
    async def _fake_verify(_settings: object, _token: str) -> AppleIdentity:
        return AppleIdentity(
            subject="apple-sub-123",
            email="appleuser@example.com",
            email_verified=True,
            name="Apple User",
        )

    monkeypatch.setattr("backend.presentation.api.v1.auth.verify_apple_id_token", _fake_verify)

    response = await async_client.post("/v1/auth/apple", json={"id_token": "fake-apple-token"})
    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert "refresh_token" in body

    user = (await db_session.execute(select(User).where(User.email == "appleuser@example.com"))).scalar_one()
    assert user.apple_subject == "apple-sub-123"


@pytest.mark.anyio
async def test_apple_login_conflict_returns_409(
    async_client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
):
    now = datetime.now(UTC)
    user = User(
        id=uuid6.uuid7(),
        email="apple-conflict@example.com",
        username="appleconflict",
        password_hash=hash_password("S3cur3P@ss!"),
        status=UserStatus.active,
        email_verified_at=now,
        apple_subject="existing-apple-subject",
    )
    db_session.add(user)
    await db_session.flush()

    async def _fake_verify(_settings: object, _token: str) -> AppleIdentity:
        return AppleIdentity(
            subject="different-apple-subject",
            email="apple-conflict@example.com",
            email_verified=True,
        )

    monkeypatch.setattr("backend.presentation.api.v1.auth.verify_apple_id_token", _fake_verify)

    response = await async_client.post("/v1/auth/apple", json={"id_token": "fake-apple-token"})
    assert response.status_code == 409


@pytest.mark.anyio
async def test_apple_login_invalid_token_returns_401(
    async_client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
):
    async def _fake_verify(_settings: object, _token: str) -> AppleIdentity:
        raise InvalidAppleTokenError("bad token")

    monkeypatch.setattr("backend.presentation.api.v1.auth.verify_apple_id_token", _fake_verify)

    response = await async_client.post("/v1/auth/apple", json={"id_token": "bad-token"})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_soundcloud_login_success_creates_or_links_user(
    async_client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
):
    async def _fake_exchange(_settings: object, *, code: str, redirect_uri: str) -> SoundCloudIdentity:
        assert code == "sc-code"
        assert redirect_uri == "echo-auth://callback"
        return SoundCloudIdentity(
            subject="soundcloud-sub-123",
            email="soundcloud-user@example.com",
            name="SC User",
        )

    monkeypatch.setattr("backend.presentation.api.v1.auth.exchange_soundcloud_code_for_identity", _fake_exchange)

    response = await async_client.post(
        "/v1/auth/soundcloud/token",
        json={"code": "sc-code", "redirect_uri": "echo-auth://callback"},
    )
    assert response.status_code == 200
    body = response.json()
    assert "access_token" in body
    assert "refresh_token" in body

    user = (await db_session.execute(select(User).where(User.email == "soundcloud-user@example.com"))).scalar_one()
    assert user.soundcloud_subject == "soundcloud-sub-123"


@pytest.mark.anyio
async def test_soundcloud_login_conflict_returns_409(
    async_client: AsyncClient,
    db_session: AsyncSession,
    monkeypatch: pytest.MonkeyPatch,
):
    now = datetime.now(UTC)
    user = User(
        id=uuid6.uuid7(),
        email="soundcloud-conflict@example.com",
        username="soundcloudconflict",
        password_hash=hash_password("S3cur3P@ss!"),
        status=UserStatus.active,
        email_verified_at=now,
        soundcloud_subject="existing-soundcloud-subject",
    )
    db_session.add(user)
    await db_session.flush()

    async def _fake_exchange(_settings: object, *, code: str, redirect_uri: str) -> SoundCloudIdentity:
        return SoundCloudIdentity(
            subject="different-soundcloud-subject",
            email="soundcloud-conflict@example.com",
            name="SC User",
        )

    monkeypatch.setattr("backend.presentation.api.v1.auth.exchange_soundcloud_code_for_identity", _fake_exchange)

    response = await async_client.post(
        "/v1/auth/soundcloud/token",
        json={"code": "sc-code", "redirect_uri": "echo-auth://callback"},
    )
    assert response.status_code == 409


@pytest.mark.anyio
async def test_soundcloud_login_invalid_token_returns_401(
    async_client: AsyncClient,
    monkeypatch: pytest.MonkeyPatch,
):
    async def _fake_exchange(_settings: object, *, code: str, redirect_uri: str) -> SoundCloudIdentity:
        raise InvalidSoundCloudTokenError("bad token")

    monkeypatch.setattr("backend.presentation.api.v1.auth.exchange_soundcloud_code_for_identity", _fake_exchange)

    response = await async_client.post(
        "/v1/auth/soundcloud/token",
        json={"code": "bad-code", "redirect_uri": "echo-auth://callback"},
    )
    assert response.status_code == 401
