"""Integration tests for AdminAction repository and related admin repositories."""

import uuid

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.security import hash_password
from backend.infrastructure.persistence.models.admin import AdminPermissionScope
from backend.infrastructure.persistence.models.admin_action import AdminActionOutcome, AdminEntityType
from backend.infrastructure.persistence.models.friend import Friend, FriendStatus
from backend.infrastructure.persistence.models.post import Post, Privacy
from backend.infrastructure.persistence.models.user import User, UserStatus
from backend.infrastructure.persistence.repositories.admin_action_repository import AdminActionRepository
from backend.infrastructure.persistence.repositories.admin_content_repository import AdminContentRepository
from backend.infrastructure.persistence.repositories.admin_friend_relationships_repository import AdminFriendRelationshipsRepository
from backend.infrastructure.persistence.repositories.admin_repository import AdminAccountRepository
from backend.infrastructure.persistence.repositories.admin_user_moderation_repository import AdminUserModerationRepository


@pytest.mark.asyncio
async def test_create_admin_action_persists(db_session: AsyncSession) -> None:
    """Creating an AdminAction persists it to the database."""
    repo = AdminActionRepository(db_session)
    admin_id = uuid.uuid4()

    action = await repo.create(
        actor_admin_id=admin_id,
        entity_type=AdminEntityType.auth,
        entity_id=None,
        operation_name="admin_login",
        outcome=AdminActionOutcome.success,
        change_payload={},
    )

    assert action.id is not None
    assert action.actor_admin_id == admin_id
    assert action.entity_type == AdminEntityType.auth
    assert action.operation_name == "admin_login"
    assert action.outcome == AdminActionOutcome.success
    assert action.change_payload == {}


@pytest.mark.asyncio
async def test_list_admin_actions_by_entity(db_session: AsyncSession) -> None:
    """Actions can be retrieved by entity type and entity id."""
    repo = AdminActionRepository(db_session)
    admin_id = uuid.uuid4()
    target_id = uuid.uuid4()

    await repo.create(
        actor_admin_id=admin_id,
        entity_type=AdminEntityType.user,
        entity_id=target_id,
        operation_name="status_change",
        outcome=AdminActionOutcome.success,
        change_payload={"old": "active", "new": "suspended"},
    )

    actions = await repo.list_by_entity(AdminEntityType.user, target_id)
    assert len(actions) >= 1
    assert any(str(a.entity_id) == str(target_id) for a in actions)


@pytest.mark.asyncio
async def test_admin_action_change_payload_is_stored(db_session: AsyncSession) -> None:
    """The change_payload JSON is stored and retrieved correctly."""
    repo = AdminActionRepository(db_session)
    payload = {"status_before": "active", "status_after": "suspended", "reason": "Test reason"}

    action = await repo.create(
        actor_admin_id=uuid.uuid4(),
        entity_type=AdminEntityType.user,
        entity_id=uuid.uuid4(),
        operation_name="user_status_change",
        outcome=AdminActionOutcome.success,
        change_payload=payload,
    )

    assert action.change_payload == payload


@pytest.mark.asyncio
async def test_list_admin_actions_by_actor(db_session: AsyncSession) -> None:
    """Actions can be retrieved by actor admin id."""
    repo = AdminActionRepository(db_session)
    actor_id = uuid.uuid4()

    await repo.create(
        actor_admin_id=actor_id,
        entity_type=AdminEntityType.user,
        entity_id=uuid.uuid4(),
        operation_name="user_status_change",
        outcome=AdminActionOutcome.success,
        change_payload={},
    )
    await repo.create(
        actor_admin_id=actor_id,
        entity_type=AdminEntityType.content,
        entity_id=uuid.uuid4(),
        operation_name="content_remove",
        outcome=AdminActionOutcome.success,
        change_payload={},
    )

    actions = await repo.list_by_actor(actor_id)
    assert len(actions) >= 2
    assert all(str(a.actor_admin_id) == str(actor_id) for a in actions)


# ---------------------------------------------------------------------------
# AdminAccountRepository
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_admin_account_repository_create(db_session: AsyncSession) -> None:
    """create() persists an AdminAccount and returns it with a generated id."""
    repo = AdminAccountRepository(db_session)

    account = await repo.create(
        email="newadmin@example.com",
        password_hash=hash_password("secret"),
        display_name="New Admin",
        permission_scope=AdminPermissionScope.full_admin,
        is_active=True,
    )

    assert account.id is not None
    assert account.email == "newadmin@example.com"
    assert account.is_active is True


@pytest.mark.asyncio
async def test_admin_account_repository_get_by_id(db_session: AsyncSession) -> None:
    """get_by_id() returns the admin by primary key."""
    repo = AdminAccountRepository(db_session)

    account = await repo.create(
        email="getbyid@example.com",
        password_hash=hash_password("secret"),
        display_name="Get By Id Admin",
    )

    fetched = await repo.get_by_id(account.id)
    assert fetched is not None
    assert str(fetched.id) == str(account.id)


@pytest.mark.asyncio
async def test_admin_account_repository_get_by_id_missing_returns_none(db_session: AsyncSession) -> None:
    """get_by_id() returns None when no record matches."""
    repo = AdminAccountRepository(db_session)
    result = await repo.get_by_id(uuid.uuid4())
    assert result is None


@pytest.mark.asyncio
async def test_admin_account_repository_set_active(db_session: AsyncSession) -> None:
    """set_active() updates is_active on the admin account."""
    repo = AdminAccountRepository(db_session)

    account = await repo.create(
        email="setactive@example.com",
        password_hash=hash_password("secret"),
        display_name="Set Active Admin",
        is_active=True,
    )

    updated = await repo.set_active(account.id, is_active=False)
    assert updated is not None
    assert updated.is_active is False


# ---------------------------------------------------------------------------
# AdminContentRepository
# ---------------------------------------------------------------------------


async def _create_user(db: AsyncSession, username: str) -> User:
    user = User(
        email=f"{username}@example.com",
        username=username,
        password_hash=hash_password("pass123"),
        status=UserStatus.active,
        preferred_genres=[],
    )
    db.add(user)
    await db.flush()
    await db.refresh(user)
    return user


@pytest.mark.asyncio
async def test_content_repo_list_managed(db_session: AsyncSession) -> None:
    """list_managed returns a list of content projections."""
    repo = AdminContentRepository(db_session)
    user = await _create_user(db_session, "contentlistuser")

    post = Post(user_id=user.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    items = await repo.list_managed(page=1, page_size=20)
    assert isinstance(items, list)
    assert any(str(i["id"]) == str(post.id) for i in items)


@pytest.mark.asyncio
async def test_content_repo_get_managed(db_session: AsyncSession) -> None:
    """get_managed returns a projection for an existing post."""
    repo = AdminContentRepository(db_session)
    user = await _create_user(db_session, "contentgetuser")

    post = Post(user_id=user.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()
    await db_session.refresh(post)

    projection = await repo.get_managed(post.id)
    assert projection["id"] == str(post.id)
    assert projection["status"] == "visible"


@pytest.mark.asyncio
async def test_content_repo_get_managed_not_found_raises(db_session: AsyncSession) -> None:
    """get_managed raises ValueError when post does not exist."""
    repo = AdminContentRepository(db_session)
    with pytest.raises(ValueError, match="not found"):
        await repo.get_managed(uuid.uuid4())


@pytest.mark.asyncio
async def test_content_repo_apply_action_remove(db_session: AsyncSession) -> None:
    """apply_action('remove') sets privacy to only_me."""
    repo = AdminContentRepository(db_session)
    user = await _create_user(db_session, "contentremoveuser")

    post = Post(user_id=user.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()
    await db_session.refresh(post)

    result = await repo.apply_action(post.id, "remove")
    assert result["status"] == "flagged"


@pytest.mark.asyncio
async def test_content_repo_apply_action_restore(db_session: AsyncSession) -> None:
    """apply_action('restore') reverts privacy to public."""
    repo = AdminContentRepository(db_session)
    user = await _create_user(db_session, "contentrestoreuser")

    post = Post(user_id=user.id, privacy=Privacy.only_me)
    db_session.add(post)
    await db_session.flush()
    await db_session.refresh(post)

    result = await repo.apply_action(post.id, "restore")
    assert result["status"] == "visible"


@pytest.mark.asyncio
async def test_content_repo_apply_action_not_found_raises(db_session: AsyncSession) -> None:
    """apply_action raises ValueError when post does not exist."""
    repo = AdminContentRepository(db_session)
    with pytest.raises(ValueError, match="not found"):
        await repo.apply_action(uuid.uuid4(), "remove")


@pytest.mark.asyncio
async def test_content_repo_delete_permanently(db_session: AsyncSession) -> None:
    """delete_permanently removes the post from the database."""
    repo = AdminContentRepository(db_session)
    user = await _create_user(db_session, "contentdeluser")

    post = Post(user_id=user.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()
    await db_session.refresh(post)
    post_id = post.id

    await repo.delete_permanently(post_id)

    with pytest.raises(ValueError):
        await repo.get_managed(post_id)


@pytest.mark.asyncio
async def test_content_repo_delete_permanently_nonexistent_is_noop(db_session: AsyncSession) -> None:
    """delete_permanently on a non-existent post does not raise."""
    repo = AdminContentRepository(db_session)
    # Should not raise
    await repo.delete_permanently(uuid.uuid4())


# ---------------------------------------------------------------------------
# AdminUserModerationRepository
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_user_moderation_repo_get_managed_not_found_raises(db_session: AsyncSession) -> None:
    """get_managed raises ValueError when user does not exist."""
    repo = AdminUserModerationRepository(db_session)
    with pytest.raises(ValueError, match="not found"):
        await repo.get_managed(uuid.uuid4())


@pytest.mark.asyncio
async def test_user_moderation_repo_list_managed_with_status_filter(db_session: AsyncSession) -> None:
    """list_managed filters by status when provided."""
    repo = AdminUserModerationRepository(db_session)
    user = await _create_user(db_session, "filtereduser")

    items = await repo.list_managed(status=["active"])
    assert any(i["id"] == str(user.id) for i in items)


@pytest.mark.asyncio
async def test_user_moderation_repo_update_status_not_found_raises(db_session: AsyncSession) -> None:
    """update_status raises ValueError for non-existent user."""
    repo = AdminUserModerationRepository(db_session)
    with pytest.raises(ValueError, match="not found"):
        await repo.update_status(uuid.uuid4(), "suspended")


@pytest.mark.asyncio
async def test_user_moderation_repo_update_status_success(db_session: AsyncSession) -> None:
    """update_status changes the user status and returns updated projection."""
    repo = AdminUserModerationRepository(db_session)
    user = await _create_user(db_session, "updatestatususer")

    result = await repo.update_status(user.id, "suspended")
    assert result["status"] == "suspended"


def test_user_moderation_repo_anonymize_email_without_at_sign() -> None:
    """_anonymize_email returns '***' when email has no '@' character."""
    from backend.infrastructure.persistence.repositories.admin_user_moderation_repository import _anonymize_email

    result = _anonymize_email("noemail")
    assert result == "***"


# ---------------------------------------------------------------------------
# AdminFriendRelationshipsRepository
# ---------------------------------------------------------------------------


async def _create_friendship(db: AsyncSession, user_a: User, user_b: User) -> Friend:
    uid_a, uid_b = user_a.id, user_b.id
    low_id, high_id = (uid_a, uid_b) if uid_a < uid_b else (uid_b, uid_a)
    friend = Friend(user1_id=low_id, user2_id=high_id, status=FriendStatus.accepted)
    db.add(friend)
    await db.flush()
    await db.refresh(friend)
    return friend


@pytest.mark.asyncio
async def test_friend_relationships_repo_get_managed_not_found_raises(db_session: AsyncSession) -> None:
    """get_managed raises ValueError when relationship does not exist."""
    repo = AdminFriendRelationshipsRepository(db_session)
    with pytest.raises(ValueError, match="not found"):
        await repo.get_managed(uuid.uuid4())


@pytest.mark.asyncio
async def test_friend_relationships_repo_get_managed_success(db_session: AsyncSession) -> None:
    """get_managed returns projection for an existing relationship."""
    repo = AdminFriendRelationshipsRepository(db_session)
    user_a = await _create_user(db_session, "frnd_get_a")
    user_b = await _create_user(db_session, "frnd_get_b")
    friendship = await _create_friendship(db_session, user_a, user_b)

    result = await repo.get_managed(friendship.id)
    assert result["id"] == str(friendship.id)


@pytest.mark.asyncio
async def test_friend_relationships_repo_apply_action_not_found_raises(db_session: AsyncSession) -> None:
    """apply_action raises ValueError for non-existent relationship."""
    repo = AdminFriendRelationshipsRepository(db_session)
    with pytest.raises(ValueError, match="not found"):
        await repo.apply_action(uuid.uuid4(), "remove")


@pytest.mark.asyncio
async def test_friend_relationships_repo_apply_action_remove(db_session: AsyncSession) -> None:
    """apply_action('remove') sets status to declined."""
    repo = AdminFriendRelationshipsRepository(db_session)
    user_a = await _create_user(db_session, "frnd_rm_a")
    user_b = await _create_user(db_session, "frnd_rm_b")
    friendship = await _create_friendship(db_session, user_a, user_b)

    result = await repo.apply_action(friendship.id, "remove")
    assert result["status"] == FriendStatus.declined.value


@pytest.mark.asyncio
async def test_friend_relationships_repo_apply_action_restore(db_session: AsyncSession) -> None:
    """apply_action('restore') sets status to accepted."""
    repo = AdminFriendRelationshipsRepository(db_session)
    user_a = await _create_user(db_session, "frnd_rs_a")
    user_b = await _create_user(db_session, "frnd_rs_b")
    friendship = await _create_friendship(db_session, user_a, user_b)

    result = await repo.apply_action(friendship.id, "restore")
    assert result["status"] == FriendStatus.accepted.value


@pytest.mark.asyncio
async def test_friend_relationships_repo_delete_permanently(db_session: AsyncSession) -> None:
    """delete_permanently removes the relationship."""
    repo = AdminFriendRelationshipsRepository(db_session)
    user_a = await _create_user(db_session, "frnd_del_a")
    user_b = await _create_user(db_session, "frnd_del_b")
    friendship = await _create_friendship(db_session, user_a, user_b)
    friendship_id = friendship.id

    await repo.delete_permanently(friendship_id)

    with pytest.raises(ValueError):
        await repo.get_managed(friendship_id)


@pytest.mark.asyncio
async def test_friend_relationships_repo_delete_permanently_nonexistent_is_noop(db_session: AsyncSession) -> None:
    """delete_permanently on non-existent relationship does not raise."""
    repo = AdminFriendRelationshipsRepository(db_session)
    await repo.delete_permanently(uuid.uuid4())
