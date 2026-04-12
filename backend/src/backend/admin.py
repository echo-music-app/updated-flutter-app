from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from backend.core.config import Settings, get_settings
from backend.core.database import get_engine
from backend.presentation.api.v1.admin import admin_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await get_engine().dispose()


def create_admin_app(settings: Settings | None = None) -> FastAPI:
    if settings is None:
        settings = get_settings()

    app = FastAPI(
        title="Echo Admin API",
        version="0.1.0",
        lifespan=lifespan,
        openapi_url="/admin/v1/openapi.json",
    )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        return JSONResponse(status_code=422, content={"detail": str(exc)})

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})

    app.include_router(admin_router)

    return app


admin_app = create_admin_app()
