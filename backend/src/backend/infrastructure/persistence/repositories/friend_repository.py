import uuid

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.domain.posts.repositories import IFriendRepository
from backend.infrastructure.persistence.models.friend import Friend, FriendStatus


class SqlAlchemyFriendRepository(IFriendRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

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
            following.append(other)
        return following
