from fastapi import APIRouter

from backend.presentation.api.v1 import v1_router
from backend.presentation.api.v1.well_known import router as well_known_router

root_router = APIRouter()
root_router.include_router(v1_router, prefix="/v1")
root_router.include_router(well_known_router)
