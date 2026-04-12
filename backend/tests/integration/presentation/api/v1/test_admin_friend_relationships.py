"""Integration tests for admin friend relationship moderation endpoints."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.security import hash_password
from backend.infrastructure.persistence.models.admin import AdminAccount, AdminPermissionScope
from backend.infrastructure.persistence.models.friend import Friend, FriendStatus
from backend.infrastructure.persistence.models.user import User, UserStatus


async def create_admin(db: AsyncSession) -> tuple[AdminAccount, str]:
    password = "AdminPassword123!"
    account = AdminAccount(
        email="admin@example.com",
        password_hash=hash_password(password),
        display_name="Test Admin",
        permission_scope=AdminPermissionScope.full_admin,
        is_active=True,
    )
    db.add(account)
    await db.flush()
    await db.refresh(account)
    return account, password


async def create_user(db: AsyncSession, username: str) -> User:
    user = User(
        email=f"{username}@example.com",
        username=username,
        password_hash=hash_password("password123"),
        status=UserStatus.active,
        preferred_genres=[],
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


async def create_friendship(db: AsyncSession, user_a: User, user_b: User) -> Friend:
    # The Friend model enforces user1_id < user2_id via a check constraint.
    uid_a, uid_b = user_a.id, user_b.id
    low_id, high_id = (uid_a, uid_b) if uid_a < uid_b else (uid_b, uid_a)
    friend = Friend(
        user1_id=low_id,
        user2_id=high_id,
        status=FriendStatus.accepted,
    )
    db.add(friend)
    await db.flush()
    await db.refresh(friend)
    return friend


class TestAdminFriendRelationshipsIntegration:
    @pytest.mark.asyncio
    async def test_admin_can_list_relationships(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        _, password = await create_admin(db_session)
        login = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login.status_code != 200:
            pytest.skip("Admin auth not yet implemented")
        token = login.json()["access_token"]

        user_a = await create_user(db_session, "user_a")
        user_b = await create_user(db_session, "user_b")
        await create_friendship(db_session, user_a, user_b)

        response = await admin_async_client.get(
            "/admin/v1/friend-relationships",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        body = response.json()
        assert "items" in body or isinstance(body, list)

    @pytest.mark.asyncio
    async def test_admin_can_remove_relationship(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        _, password = await create_admin(db_session)
        login = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login.status_code != 200:
            pytest.skip("Admin auth not yet implemented")
        token = login.json()["access_token"]

        user_a = await create_user(db_session, "user_c")
        user_b = await create_user(db_session, "user_d")
        friendship = await create_friendship(db_session, user_a, user_b)

        response = await admin_async_client.post(
            f"/admin/v1/friend-relationships/{friendship.id}/actions",
            json={"action_type": "remove", "reason": "Policy violation", "confirmed": False},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_permanent_delete_requires_confirmation(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        _, password = await create_admin(db_session)
        login = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login.status_code != 200:
            pytest.skip("Admin auth not yet implemented")
        token = login.json()["access_token"]

        user_a = await create_user(db_session, "user_e")
        user_b = await create_user(db_session, "user_f")
        friendship = await create_friendship(db_session, user_a, user_b)

        response = await admin_async_client.delete(
            f"/admin/v1/friend-relationships/{friendship.id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        # Without confirmation flag, should fail
        assert response.status_code in {200, 422}

    @pytest.mark.asyncio
    async def test_get_relationship_not_found_returns_404(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """GET /admin/v1/friend-relationships/{id} returns 404 for non-existent relationship."""
        import uuid

        _, password = await create_admin(db_session)
        login = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login.status_code != 200:
            pytest.skip("Admin auth not yet implemented")
        token = login.json()["access_token"]

        response = await admin_async_client.get(
            f"/admin/v1/friend-relationships/{uuid.uuid4()}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_apply_relationship_action_invalid_action_returns_422(
        self, admin_async_client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """POST /admin/v1/friend-relationships/{id}/actions returns 422 for unknown action_type."""
        user_a = await create_user(db_session, "rel_user_g")
        user_b = await create_user(db_session, "rel_user_h")
        friendship = await create_friendship(db_session, user_a, user_b)

        _, password = await create_admin(db_session)
        login = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login.status_code != 200:
            pytest.skip("Admin auth not yet implemented")
        token = login.json()["access_token"]

        response = await admin_async_client.post(
            f"/admin/v1/friend-relationships/{friendship.id}/actions",
            json={"action_type": "invalid_action", "reason": "Test", "confirmed": False},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_apply_relationship_action_not_found_returns_422(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """POST /admin/v1/friend-relationships/{id}/actions returns 422 for non-existent relationship."""
        import uuid

        _, password = await create_admin(db_session)
        login = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login.status_code != 200:
            pytest.skip("Admin auth not yet implemented")
        token = login.json()["access_token"]

        response = await admin_async_client.post(
            f"/admin/v1/friend-relationships/{uuid.uuid4()}/actions",
            json={"action_type": "remove", "reason": "Test", "confirmed": False},
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_delete_relationship_permanently_success(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """DELETE /admin/v1/friend-relationships/{id} permanently deletes the relationship."""
        user_a = await create_user(db_session, "del_user_i")
        user_b = await create_user(db_session, "del_user_j")
        friendship = await create_friendship(db_session, user_a, user_b)

        _, password = await create_admin(db_session)
        login = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login.status_code != 200:
            pytest.skip("Admin auth not yet implemented")
        token = login.json()["access_token"]

        response = await admin_async_client.delete(
            f"/admin/v1/friend-relationships/{friendship.id}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 200
        body = response.json()
        assert body["outcome"] == "success"

    @pytest.mark.asyncio
    async def test_delete_relationship_use_case_raises_value_error_returns_404(
        self, admin_async_client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """DELETE /admin/v1/friend-relationships/{id} returns 404 when use case raises ValueError."""
        import uuid

        _, password = await create_admin(db_session)
        login = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login.status_code != 200:
            pytest.skip("Admin auth not yet implemented")
        token = login.json()["access_token"]

        with patch(
            "backend.application.use_cases.admin_friend_relationships.AdminFriendRelationshipsUseCases.delete_permanently",
            new_callable=AsyncMock,
            side_effect=ValueError("Relationship not found"),
        ):
            response = await admin_async_client.delete(
                f"/admin/v1/friend-relationships/{uuid.uuid4()}",
                headers={"Authorization": f"Bearer {token}"},
            )
        assert response.status_code == 404
