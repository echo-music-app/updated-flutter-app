from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from backend.core.config import Settings, get_settings
from backend.core.database import get_engine
from backend.presentation.api.router import root_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield
    await get_engine().dispose()


def create_app(settings: Settings | None = None) -> FastAPI:
    if settings is None:
        settings = get_settings()

    app = FastAPI(
        title="Echo API",
        version="0.1.0",
        lifespan=lifespan,
        openapi_url="/v1/openapi.json",
    )

    if settings.cors_allowed_origins:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=settings.cors_allowed_origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(request: Request, exc: RequestValidationError):
        return JSONResponse(status_code=422, content={"detail": str(exc)})

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(request: Request, exc: Exception):
        if settings.debug:
            return JSONResponse(
                status_code=500,
                content={
                    "detail": str(exc) or exc.__class__.__name__,
                    "error_type": exc.__class__.__name__,
                },
            )
        return JSONResponse(status_code=500, content={"detail": "Internal server error"})

    app.include_router(root_router)

    return app


app = create_app()
