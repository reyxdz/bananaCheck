"""API tests for ``GET /health`` (B24).

The health endpoint must stay trivially available: it reports that the service
is up and must not depend on the model being loadable, so it can be polled while
the model is missing or being swapped.
"""

from fastapi.testclient import TestClient

from backend.app.config import BackendConfig
from backend.app.main import create_app

_EXPECTED_BODY = {
    "status": "ok",
    "service": "banana-classifier-model-management",
}


def test_health_reports_service_ready() -> None:
    client = TestClient(create_app())

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == _EXPECTED_BODY


def test_health_returns_json_content_type() -> None:
    response = TestClient(create_app()).get("/health")
    assert response.headers["content-type"].startswith("application/json")


def test_health_does_not_depend_on_the_model(tmp_path) -> None:
    """Health must succeed even when the model and labels are absent.

    A health check that fails because the model is missing is useless for
    telling "service down" apart from "model not provisioned".
    """
    config = BackendConfig(
        model_path=tmp_path / "absent.tflite",
        labels_path=tmp_path / "absent.txt",
    )
    client = TestClient(create_app(config))

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == _EXPECTED_BODY


def test_health_rejects_post() -> None:
    """Only GET is defined; other methods must be refused, not silently handled."""
    assert TestClient(create_app()).post("/health").status_code == 405


def test_health_is_documented_in_openapi() -> None:
    spec = create_app().openapi()
    assert "/health" in spec["paths"]
    assert "get" in spec["paths"]["/health"]
