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
async def test_list_threads_requires_auth(async_client_no_db: AsyncClient):
    response = await async_client_no_db.get("/v1/messages/threads")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_send_message_requires_auth(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post(
        "/v1/messages/00000000-0000-0000-0000-000000000001",
        json={"text": "hello"},
    )
    assert response.status_code == 401


@pytest.mark.anyio
async def test_non_friend_cannot_send_message(async_client: AsyncClient):
    token_a = await _register(async_client, "msg_a@example.com", "msg_a")
    token_b = await _register(async_client, "msg_b@example.com", "msg_b")

    me_b = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token_b}"})
    target_id = me_b.json()["id"]

    response = await async_client.post(
        f"/v1/messages/{target_id}",
        headers={"Authorization": f"Bearer {token_a}"},
        json={"text": "hey there"},
    )
    assert response.status_code == 403


@pytest.mark.anyio
async def test_friends_can_send_and_list_messages(async_client: AsyncClient):
    token_a = await _register(async_client, "msg_friend_a@example.com", "msg_friend_a")
    token_b = await _register(async_client, "msg_friend_b@example.com", "msg_friend_b")

    me_b = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token_b}"})
    user_b_id = me_b.json()["id"]

    request_resp = await async_client.post(
        f"/v1/friends/{user_b_id}/request",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert request_resp.status_code == 200

    me_a = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token_a}"})
    user_a_id = me_a.json()["id"]

    accept_resp = await async_client.post(
        f"/v1/friends/{user_a_id}/accept",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert accept_resp.status_code == 200

    send_resp = await async_client.post(
        f"/v1/messages/{user_b_id}",
        headers={"Authorization": f"Bearer {token_a}"},
        json={"text": "hello my friend"},
    )
    assert send_resp.status_code == 201
    assert send_resp.json()["text"] == "hello my friend"

    list_resp = await async_client.get(
        f"/v1/messages/{user_b_id}",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert list_resp.status_code == 200
    assert list_resp.json()["target_user_id"] == user_b_id
    assert len(list_resp.json()["items"]) == 1
    assert list_resp.json()["items"][0]["text"] == "hello my friend"

    threads_resp = await async_client.get(
        "/v1/messages/threads",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert threads_resp.status_code == 200
    assert len(threads_resp.json()) == 1
    assert threads_resp.json()[0]["user_id"] == user_b_id
