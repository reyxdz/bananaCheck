from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import BackendConfig, get_config
from .routers import classify, health, models, retraining


def create_app(config: BackendConfig | None = None) -> FastAPI:
    config = config or get_config()
    app = FastAPI(
        title=config.title,
        version=config.version,
    )
    # Dev-only CORS: the shipped app never calls this backend, so origins are
    # restricted to local development tools (Swagger UI, browser clients).
    app.add_middleware(
        CORSMiddleware,
        allow_origins=list(config.cors_allow_origins),
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(health.router)
    app.include_router(classify.router)
    app.include_router(models.router, prefix="/api")
    app.include_router(retraining.router, prefix="/api")
    return app


app = create_app()
