import uuid
from datetime import datetime

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import aliased

from backend.domain.posts.repositories import IFriendRepository
from backend.infrastructure.persistence.models.friend import Friend, FriendStatus
from backend.infrastructure.persistence.models.user import User


class SqlAlchemyFriendRepository(IFriendRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    @staticmethod
    def _ordered_pair(a: uuid.UUID, b: uuid.UUID) -> tuple[uuid.UUID, uuid.UUID]:
        return (a, b) if a.int < b.int else (b, a)

    async def get_relationship_status(
        self,
        user_id: uuid.UUID,
        target_user_id: uuid.UUID,
    ) -> str:
        if user_id == target_user_id:
            return "self"

        user1_id, user2_id = self._ordered_pair(user_id, target_user_id)
        stmt = select(Friend).where(and_(Friend.user1_id == user1_id, Friend.user2_id == user2_id))
        relationship = (await self._session.execute(stmt)).scalar_one_or_none()
        if relationship is None:
            return "none"
        if relationship.status == FriendStatus.accepted:
            return "accepted"
        if relationship.status == FriendStatus.pending:
            if relationship.requested_by_id is None:
                return "pending_outgoing"
            return "pending_outgoing" if relationship.requested_by_id == user_id else "pending_incoming"
        return "none"

    async def send_follow_request(
        self,
        user_id: uuid.UUID,
        target_user_id: uuid.UUID,
    ) -> Friend:
        if user_id == target_user_id:
            raise ValueError("Cannot follow yourself")

        user1_id, user2_id = self._ordered_pair(user_id, target_user_id)
        stmt = select(Friend).where(and_(Friend.user1_id == user1_id, Friend.user2_id == user2_id))
        relationship = (await self._session.execute(stmt)).scalar_one_or_none()

        if relationship is None:
            relationship = Friend(
                user1_id=user1_id,
                user2_id=user2_id,
                requested_by_id=user_id,
                status=FriendStatus.pending,
            )
            self._session.add(relationship)
        else:
            if relationship.status == FriendStatus.accepted:
                await self._session.refresh(relationship)
                return relationship

            if (
                relationship.status == FriendStatus.pending
                and relationship.requested_by_id is not None
                and relationship.requested_by_id != user_id
            ):
                relationship.status = FriendStatus.accepted
            else:
                relationship.status = FriendStatus.pending
                relationship.requested_by_id = user_id

        await self._session.flush()
        await self._session.refresh(relationship)
        return relationship

    async def accept_follow_request(
        self,
        user_id: uuid.UUID,
        target_user_id: uuid.UUID,
    ) -> Friend:
        if user_id == target_user_id:
            raise ValueError("Cannot accept your own request")

        user1_id, user2_id = self._ordered_pair(user_id, target_user_id)
        stmt = select(Friend).where(and_(Friend.user1_id == user1_id, Friend.user2_id == user2_id))
        relationship = (await self._session.execute(stmt)).scalar_one_or_none()
        if relationship is None:
            raise ValueError("No follow request found")
        if relationship.status != FriendStatus.pending:
            await self._session.refresh(relationship)
            return relationship
        if relationship.requested_by_id == user_id:
            raise ValueError("Cannot accept a request you sent")

        relationship.status = FriendStatus.accepted
        await self._session.flush()
        await self._session.refresh(relationship)
        return relationship

    async def get_following_user_ids(self, user_id: uuid.UUID) -> list[uuid.UUID]:
        stmt = select(Friend).where(
            and_(
                Friend.status == FriendStatus.accepted,
                or_(Friend.user1_id == user_id, Friend.user2_id == user_id),
            )
        )
        rows = (await self._session.execute(stmt)).scalars().all()
        following: list[uuid.UUID] = []
        for row in rows:
            other = row.user2_id if row.user1_id == user_id else row.user1_id
            if row.requested_by_id is None:
                following.append(other)
                continue
            if row.requested_by_id == user_id:
                following.append(other)
        return following

    async def are_friends(self, user_id: uuid.UUID, target_user_id: uuid.UUID) -> bool:
        if user_id == target_user_id:
            return True
        user1_id, user2_id = self._ordered_pair(user_id, target_user_id)
        stmt = select(Friend.status).where(
            and_(Friend.user1_id == user1_id, Friend.user2_id == user2_id)
        )
        status = (await self._session.execute(stmt)).scalar_one_or_none()
        return status == FriendStatus.accepted

    async def get_follower_following_counts(
        self,
        user_id: uuid.UUID,
    ) -> tuple[int, int]:
        stmt = select(Friend).where(
            and_(
                Friend.status == FriendStatus.accepted,
                or_(Friend.user1_id == user_id, Friend.user2_id == user_id),
            )
        )
        rows = (await self._session.execute(stmt)).scalars().all()

        followers = 0
        following = 0
        for row in rows:
            if row.requested_by_id is None:
                followers += 1
                following += 1
                continue

            target_id = row.user2_id if row.requested_by_id == row.user1_id else row.user1_id
            if target_id == user_id:
                followers += 1
            else:
                following += 1

        return followers, following

    async def list_incoming_follow_requests(
        self,
        user_id: uuid.UUID,
    ) -> list[tuple[uuid.UUID, str, datetime]]:
        requester = aliased(User)
        stmt = (
            select(Friend, requester.username)
            .join(requester, requester.id == Friend.requested_by_id)
            .where(
                and_(
                    Friend.status == FriendStatus.pending,
                    Friend.requested_by_id.is_not(None),
                    Friend.requested_by_id != user_id,
                    or_(Friend.user1_id == user_id, Friend.user2_id == user_id),
                )
            )
            .order_by(Friend.created_at.desc())
        )

        rows = (await self._session.execute(stmt)).all()
        return [
            (
                row[0].requested_by_id,
                row[1],
                row[0].created_at,
            )
            for row in rows
            if row[0].requested_by_id is not None
        ]

    async def list_accepted_friends(
        self,
        user_id: uuid.UUID,
    ) -> list[tuple[uuid.UUID, str, str | None]]:
        stmt = (
            select(Friend)
            .where(
                and_(
                    Friend.status == FriendStatus.accepted,
                    or_(Friend.user1_id == user_id, Friend.user2_id == user_id),
                )
            )
            .order_by(Friend.updated_at.desc())
        )
        relationships = (await self._session.execute(stmt)).scalars().all()
        if not relationships:
            return []

        friend_ids: list[uuid.UUID] = []
        for relationship in relationships:
            friend_ids.append(
                relationship.user2_id
                if relationship.user1_id == user_id
                else relationship.user1_id
            )

        users = (
            await self._session.execute(
                select(User.id, User.username, User.avatar_path).where(User.id.in_(friend_ids))
            )
        ).all()
        users_by_id = {user_id_value: (username, avatar_path) for user_id_value, username, avatar_path in users}

        results: list[tuple[uuid.UUID, str, str | None]] = []
        for friend_id in friend_ids:
            username, avatar_path = users_by_id.get(friend_id, ("Unknown user", None))
            results.append((friend_id, username, avatar_path))
        return results

    async def list_followers(
        self,
        user_id: uuid.UUID,
    ) -> list[tuple[uuid.UUID, str, str | None]]:
        stmt = (
            select(Friend)
            .where(
                and_(
                    Friend.status == FriendStatus.accepted,
                    or_(Friend.user1_id == user_id, Friend.user2_id == user_id),
                )
            )
            .order_by(Friend.updated_at.desc())
        )
        relationships = (await self._session.execute(stmt)).scalars().all()
        if not relationships:
            return []

        follower_ids: list[uuid.UUID] = []
        for relationship in relationships:
            if relationship.requested_by_id is None:
                follower_ids.append(
                    relationship.user2_id
                    if relationship.user1_id == user_id
                    else relationship.user1_id
                )
                continue

            target_id = (
                relationship.user2_id
                if relationship.requested_by_id == relationship.user1_id
                else relationship.user1_id
            )
            if target_id == user_id and relationship.requested_by_id is not None:
                follower_ids.append(relationship.requested_by_id)

        return await self._list_users_with_avatar(follower_ids)

    async def list_following(
        self,
        user_id: uuid.UUID,
    ) -> list[tuple[uuid.UUID, str, str | None]]:
        stmt = (
            select(Friend)
            .where(
                and_(
                    Friend.status == FriendStatus.accepted,
                    or_(Friend.user1_id == user_id, Friend.user2_id == user_id),
                )
            )
            .order_by(Friend.updated_at.desc())
        )
        relationships = (await self._session.execute(stmt)).scalars().all()
        if not relationships:
            return []

        following_ids: list[uuid.UUID] = []
        for relationship in relationships:
            if relationship.requested_by_id is None:
                following_ids.append(
                    relationship.user2_id
                    if relationship.user1_id == user_id
                    else relationship.user1_id
                )
                continue

            if relationship.requested_by_id == user_id:
                following_ids.append(
                    relationship.user2_id
                    if relationship.user1_id == user_id
                    else relationship.user1_id
                )

        return await self._list_users_with_avatar(following_ids)

    async def _list_users_with_avatar(
        self,
        user_ids: list[uuid.UUID],
    ) -> list[tuple[uuid.UUID, str, str | None]]:
        if not user_ids:
            return []
        users = (
            await self._session.execute(
                select(User.id, User.username, User.avatar_path).where(User.id.in_(user_ids))
            )
        ).all()
        users_by_id = {user_id_value: (username, avatar_path) for user_id_value, username, avatar_path in users}

        results: list[tuple[uuid.UUID, str, str | None]] = []
        for item_user_id in user_ids:
            username, avatar_path = users_by_id.get(item_user_id, ("Unknown user", None))
            results.append((item_user_id, username, avatar_path))
        return results
