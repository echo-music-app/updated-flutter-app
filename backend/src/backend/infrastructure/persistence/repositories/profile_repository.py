"""SQLAlchemy profile repository — read and update projections."""

import uuid

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backend.domain.profiles.entities.profile import MeProfile, PublicUserProfile
from backend.domain.profiles.exceptions import ProfileNotFoundError, UsernameConflictError
from backend.infrastructure.persistence.models.user import User, UserStatus
from backend.infrastructure.persistence.repositories.friend_repository import (
    SqlAlchemyFriendRepository,
)


class SqlAlchemyProfileRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_public_by_id(self, user_id: uuid.UUID) -> PublicUserProfile | None:
        result = await self._session.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            return None
        followers_count, following_count = await SqlAlchemyFriendRepository(
            self._session
        ).get_follower_following_counts(user.id)
        return PublicUserProfile(
            id=user.id,
            username=user.username,
            avatar_path=user.avatar_path,
            bio=user.bio,
            preferred_genres=list(user.preferred_genres),
            is_artist=user.is_artist,
            followers_count=followers_count,
            following_count=following_count,
            created_at=user.created_at,
        )

    async def search_public_by_username(
        self,
        query: str,
        *,
        limit: int,
        exclude_user_id: uuid.UUID | None = None,
    ) -> list[PublicUserProfile]:
        stmt = (
            select(User)
            .where(User.status == UserStatus.active)
            .where(User.username.ilike(f"%{query}%"))
            .order_by(User.username.asc())
            .limit(limit)
        )
        if exclude_user_id is not None:
            stmt = stmt.where(User.id != exclude_user_id)

        result = await self._session.execute(stmt)
        users = result.scalars().all()
        return [
            PublicUserProfile(
                id=user.id,
                username=user.username,
                avatar_path=user.avatar_path,
                bio=user.bio,
                preferred_genres=list(user.preferred_genres),
                is_artist=user.is_artist,
                followers_count=0,
                following_count=0,
                created_at=user.created_at,
            )
            for user in users
        ]

    async def get_me_by_id(self, user_id: uuid.UUID) -> MeProfile | None:
        result = await self._session.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            return None
        followers_count, following_count = await SqlAlchemyFriendRepository(
            self._session
        ).get_follower_following_counts(user.id)
        return _user_to_me_profile(user, followers_count, following_count)

    async def update_me(
        self,
        user_id: uuid.UUID,
        *,
        username: str | None = None,
        bio: str | None = None,
        preferred_genres: list[str] | None = None,
    ) -> MeProfile:
        result = await self._session.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise ProfileNotFoundError(f"User {user_id} not found")

        if username is not None:
            user.username = username
        if bio is not None:
            user.bio = bio
        if preferred_genres is not None:
            user.preferred_genres = preferred_genres

        try:
            await self._session.flush()
        except IntegrityError as exc:
            await self._session.rollback()
            raise UsernameConflictError("Username already taken") from exc

        await self._session.refresh(user)
        followers_count, following_count = await SqlAlchemyFriendRepository(
            self._session
        ).get_follower_following_counts(user.id)
        return _user_to_me_profile(user, followers_count, following_count)

    async def update_me_avatar(
        self,
        user_id: uuid.UUID,
        *,
        avatar_path: str,
    ) -> MeProfile:
        result = await self._session.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise ProfileNotFoundError(f"User {user_id} not found")

        user.avatar_path = avatar_path
        await self._session.flush()
        await self._session.refresh(user)
        followers_count, following_count = await SqlAlchemyFriendRepository(
            self._session
        ).get_follower_following_counts(user.id)
        return _user_to_me_profile(user, followers_count, following_count)


def _user_to_me_profile(
    user: User,
    followers_count: int,
    following_count: int,
) -> MeProfile:
    return MeProfile(
        id=user.id,
        email=user.email,
        username=user.username,
        avatar_path=user.avatar_path,
        bio=user.bio,
        preferred_genres=list(user.preferred_genres),
        status=str(user.status.value if hasattr(user.status, "value") else user.status),
        is_artist=user.is_artist,
        followers_count=followers_count,
        following_count=following_count,
        created_at=user.created_at,
        updated_at=user.updated_at,
    )
