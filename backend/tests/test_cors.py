from fastapi.testclient import TestClient

from backend.app.config import BackendConfig
from backend.app.main import create_app


def _client(*origins: str) -> TestClient:
    config = BackendConfig(cors_allow_origins=tuple(origins))
    return TestClient(create_app(config))


def test_allowed_origin_is_echoed_on_simple_request() -> None:
    client = _client("http://localhost")

    response = client.get("/health", headers={"Origin": "http://localhost"})

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost"


def test_preflight_from_allowed_origin_is_permitted() -> None:
    client = _client("http://localhost")

    response = client.options(
        "/health",
        headers={
            "Origin": "http://localhost",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost"


def test_disallowed_origin_is_not_granted() -> None:
    client = _client("http://localhost")

    response = client.get(
        "/health", headers={"Origin": "http://evil.example"}
    )

    # The endpoint still responds, but no CORS grant is returned to the browser.
    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers
