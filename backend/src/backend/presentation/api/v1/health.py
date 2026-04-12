from importlib.metadata import version

from fastapi import APIRouter
from pydantic import BaseModel

from backend.core.decorators import public_endpoint

router = APIRouter()


class HealthResponse(BaseModel):
    status: str
    version: str


@router.get("/health", response_model=HealthResponse)
@public_endpoint
async def health_check():
    return HealthResponse(status="ok", version=version("backend"))
