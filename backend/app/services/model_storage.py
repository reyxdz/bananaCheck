from pathlib import Path
from typing import Protocol, runtime_checkable


@runtime_checkable
class ModelStorage(Protocol):
    async def save(self, filename: str, content: bytes) -> Path:
        ...
