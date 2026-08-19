from backend.app.routers.models import router as models_router
from backend.app.routers.retraining import router as retraining_router


def test_future_routers_have_stable_prefixes_without_fake_routes() -> None:
    assert models_router.prefix == "/models"
    assert retraining_router.prefix == "/retraining"
    assert models_router.routes == []
    assert retraining_router.routes == []
