"""``POST /classify`` — batch-test the model with images (B19, dev-only).

Lets the model be exercised straight from the shell during tuning, without
building the Flutter app::

    curl -X POST http://127.0.0.1:8000/classify -F image=@banana.jpg

The model is loaded once per process and cached, so scripting hundreds of
images stays fast.
"""

from __future__ import annotations

from functools import lru_cache

from fastapi import (
    APIRouter,
    Depends,
    File,
    HTTPException,
    Request,
    UploadFile,
    status,
)

from ..config import BackendConfig
from ..models.schemas import ClassificationResponse
from ..services.inference import (
    InferenceService,
    InvalidImageError,
    ModelUnavailableError,
    load_tflite_predictor,
)
from ..services.preprocessing import UnsupportedImageFormatError

router = APIRouter(tags=["classify"])


def get_backend_config(request: Request) -> BackendConfig:
    """Return the config the app was created with (set in ``create_app``)."""
    return request.app.state.config


def build_inference_service(config: BackendConfig) -> InferenceService:
    """Construct an :class:`InferenceService` from *config*.

    Raises
    ------
    ModelUnavailableError
        If the labels file or the model cannot be loaded.
    """
    labels = config.load_labels()
    if not labels:
        raise ModelUnavailableError(
            f"No labels found at {config.labels_path}. Point BANANA_LABELS_PATH "
            "at the labels.txt that ships with the model."
        )
    return InferenceService(
        labels=labels,
        predict=load_tflite_predictor(config.model_path),
    )


@lru_cache(maxsize=2)
def _cached_inference_service(config: BackendConfig) -> InferenceService:
    """Load the model once per distinct config.

    Keyed on the whole (frozen, hashable) config so an app built with a custom
    ``model_path`` loads *that* model instead of silently reusing the default —
    while repeated requests against the same config still load the model once.
    """
    return build_inference_service(config)


def get_inference_service(
    config: BackendConfig = Depends(get_backend_config),
) -> InferenceService:
    """FastAPI dependency; override in tests to inject a stub service."""
    try:
        return _cached_inference_service(config)
    except ModelUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc


@router.post(
    "/classify",
    response_model=ClassificationResponse,
    summary="Classify a banana image (dev-only batch testing)",
)
async def classify(
    image: UploadFile = File(description="Banana image (JPEG or PNG)."),
    service: InferenceService = Depends(get_inference_service),
    config: BackendConfig = Depends(get_backend_config),
) -> ClassificationResponse:
    """Run the bundled TFLite model over one uploaded image."""

    # Size is checked before decoding so an oversized payload never reaches the
    # image decoder (B23).
    declared_size = image.size
    if declared_size is not None and declared_size > config.max_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=(
                f"Image is {declared_size} bytes; the limit is "
                f"{config.max_upload_bytes} bytes."
            ),
        )

    contents = await image.read()
    if not contents:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )
    if len(contents) > config.max_upload_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail=(
                f"Image is {len(contents)} bytes; the limit is "
                f"{config.max_upload_bytes} bytes."
            ),
        )

    try:
        return service.classify(contents)
    except UnsupportedImageFormatError as exc:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=str(exc),
        ) from exc
    except InvalidImageError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc
    except ModelUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=str(exc),
        ) from exc
