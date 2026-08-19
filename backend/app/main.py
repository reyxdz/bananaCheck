from fastapi import FastAPI

from .routers import health, models, retraining


def create_app() -> FastAPI:
    app = FastAPI(
        title="Banana Classifier Model Management",
        version="0.1.0",
    )
    app.include_router(health.router)
    app.include_router(models.router, prefix="/api")
    app.include_router(retraining.router, prefix="/api")
    return app


app = create_app()
