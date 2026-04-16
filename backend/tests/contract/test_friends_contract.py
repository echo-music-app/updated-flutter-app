import pytest
from httpx import AsyncClient


async def _register(client: AsyncClient, email: str, username: str) -> str:
    reg_resp = await client.post(
        "/v1/auth/register",
        json={"email": email, "username": username, "password": "password123"},
    )
    assert reg_resp.status_code == 201
    verification_code = reg_resp.json()["verification_code"]
    verify_resp = await client.post(
        "/v1/auth/verify-email",
        json={"email": email, "code": verification_code},
    )
    assert verify_resp.status_code == 200
    return verify_resp.json()["access_token"]


@pytest.mark.anyio
async def test_follow_requires_auth(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post("/v1/friends/00000000-0000-0000-0000-000000000001/request")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_list_incoming_requests_requires_auth(async_client_no_db: AsyncClient):
    response = await async_client_no_db.get("/v1/friends/requests/incoming")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_list_friends_requires_auth(async_client_no_db: AsyncClient):
    response = await async_client_no_db.get("/v1/friends")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_list_followers_and_following_require_auth(async_client_no_db: AsyncClient):
    followers = await async_client_no_db.get("/v1/friends/followers")
    following = await async_client_no_db.get("/v1/friends/following")
    assert followers.status_code == 401
    assert following.status_code == 401


@pytest.mark.anyio
async def test_follow_request_accept_and_status(async_client: AsyncClient):
    token_a = await _register(async_client, "friends_a@example.com", "friends_a")
    token_b = await _register(async_client, "friends_b@example.com", "friends_b")

    me_a = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token_a}"})
    user_a_id = me_a.json()["id"]
    me_b = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token_b}"})
    target_id = me_b.json()["id"]

    request_resp = await async_client.post(
        f"/v1/friends/{target_id}/request",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert request_resp.status_code == 200
    assert request_resp.json()["status"] == "pending_outgoing"

    status_resp = await async_client.get(
        f"/v1/friends/{target_id}/status",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert status_resp.status_code == 200
    assert status_resp.json()["status"] == "pending_outgoing"
    assert status_resp.json()["is_following"] is False

    accept_resp = await async_client.post(
        f"/v1/friends/{me_b.json()['id']}/accept",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert accept_resp.status_code == 200

    status_after_accept = await async_client.get(
        f"/v1/friends/{target_id}/status",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert status_after_accept.status_code == 200
    assert status_after_accept.json()["status"] == "accepted"
    assert status_after_accept.json()["is_following"] is True
    assert status_resp.json()["is_following"] is True

    friends_resp = await async_client.get(
        "/v1/friends",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert friends_resp.status_code == 200
    assert any(
        item["user_id"] == target_id and item["username"] == "friends_b"
        for item in friends_resp.json()
    )

    following_resp = await async_client.get(
        "/v1/friends/following",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert following_resp.status_code == 200
    assert any(item["user_id"] == target_id for item in following_resp.json())

    followers_resp = await async_client.get(
        "/v1/friends/followers",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert followers_resp.status_code == 200
    assert any(item["user_id"] == user_a_id for item in followers_resp.json())
