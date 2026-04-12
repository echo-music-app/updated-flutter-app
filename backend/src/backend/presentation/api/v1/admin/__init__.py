from fastapi import APIRouter

from backend.presentation.api.v1.admin.auth import router as admin_auth_router
from backend.presentation.api.v1.admin.content import router as admin_content_router
from backend.presentation.api.v1.admin.friend_relationships import router as admin_friend_relationships_router
from backend.presentation.api.v1.admin.users import router as admin_users_router

admin_router = APIRouter(prefix="/admin/v1", tags=["admin"])
admin_router.include_router(admin_auth_router)
admin_router.include_router(admin_users_router)
admin_router.include_router(admin_content_router)
admin_router.include_router(admin_friend_relationships_router)
