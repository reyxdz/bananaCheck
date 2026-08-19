from pathlib import Path
from typing import Protocol, runtime_checkable


@runtime_checkable
class RetrainingService(Protocol):
    async def start(self, dataset_path: Path) -> str:
        ...
