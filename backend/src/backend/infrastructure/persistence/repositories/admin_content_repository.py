"""Admin content moderation repository.

Returns managed admin-facing projections over Post records.
Sensitive fields are excluded from projections.
"""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.post import Post, Privacy


class AdminContentRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    def _to_projection(self, post: Post) -> dict:
        return {
            "id": str(post.id),
            "owner_user_id": str(post.user_id),
            "status": "visible" if post.privacy != Privacy.only_me else "flagged",
            "content_type": "post",
            "preview_text": None,  # not exposed to admin by default
            "created_at": post.created_at.isoformat() if hasattr(post, "created_at") else None,
        }

    async def list_managed(
        self,
        *,
        page: int = 1,
        page_size: int = 20,
        query: str | None = None,
        status: list[str] | None = None,
    ) -> list[dict]:
        stmt = select(Post).offset((page - 1) * page_size).limit(page_size)
        result = await self._db.execute(stmt)
        return [self._to_projection(p) for p in result.scalars().all()]

    async def get_managed(self, content_id: uuid.UUID) -> dict:
        result = await self._db.execute(select(Post).where(Post.id == content_id))
        post = result.scalar_one_or_none()
        if post is None:
            raise ValueError(f"Content {content_id} not found")
        return self._to_projection(post)

    async def apply_action(self, content_id: uuid.UUID, action_type: str) -> dict:
        result = await self._db.execute(select(Post).where(Post.id == content_id))
        post = result.scalar_one_or_none()
        if post is None:
            raise ValueError(f"Content {content_id} not found")
        # action_type handling: remove sets privacy to only_me; restore reverts to public
        if action_type == "remove":
            post.privacy = Privacy.only_me
        elif action_type == "restore":
            post.privacy = Privacy.public
        await self._db.flush()
        return self._to_projection(post)

    async def delete_permanently(self, content_id: uuid.UUID) -> None:
        result = await self._db.execute(select(Post).where(Post.id == content_id))
        post = result.scalar_one_or_none()
        if post is not None:
            await self._db.delete(post)
            await self._db.flush()
