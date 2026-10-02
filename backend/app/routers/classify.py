"""``POST /classify`` — batch-test the model with images (B19, dev-only).

Lets the model be exercised straight from the shell during tuning, without
building the Flutter app::

    curl -X POST http://127.0.0.1:8000/classify -F image=@banana.jpg

The model is loaded once per process and cached, so scripting hundreds of
images stays fast.
"""

from __future__ import annotations

from functools import lru_cache

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from ..config import BackendConfig, get_config
from ..models.schemas import ClassificationResponse
from ..services.inference import (
    InferenceService,
    InvalidImageError,
    ModelUnavailableError,
    load_tflite_predictor,
)

router = APIRouter(tags=["classify"])


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


@lru_cache(maxsize=1)
def _cached_inference_service() -> InferenceService:
    """Load the model once per process."""
    return build_inference_service(get_config())


def get_inference_service() -> InferenceService:
    """FastAPI dependency; override in tests to inject a stub service."""
    try:
        return _cached_inference_service()
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
) -> ClassificationResponse:
    """Run the bundled TFLite model over one uploaded image."""
    contents = await image.read()
    if not contents:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Uploaded file is empty.",
        )

    try:
        return service.classify(contents)
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
