import uuid

from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.admin import AdminAccount, AdminPermissionScope


class AdminAccountRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def get_by_email(self, email: str) -> AdminAccount | None:
        result = await self._db.execute(select(AdminAccount).where(AdminAccount.email == email))
        return result.scalar_one_or_none()

    async def get_by_id(self, admin_id: uuid.UUID) -> AdminAccount | None:
        result = await self._db.execute(select(AdminAccount).where(AdminAccount.id == admin_id))
        return result.scalar_one_or_none()

    async def create(
        self,
        *,
        email: str,
        password_hash: str,
        display_name: str,
        permission_scope: AdminPermissionScope = AdminPermissionScope.full_admin,
        is_active: bool = True,
    ) -> AdminAccount:
        account = AdminAccount(
            email=email,
            password_hash=password_hash,
            display_name=display_name,
            permission_scope=permission_scope,
            is_active=is_active,
        )
        self._db.add(account)
        await self._db.flush()
        await self._db.refresh(account)
        return account

    async def set_active(self, admin_id: uuid.UUID, *, is_active: bool) -> AdminAccount | None:
        await self._db.execute(update(AdminAccount).where(AdminAccount.id == admin_id).values(is_active=is_active))
        return await self.get_by_id(admin_id)
