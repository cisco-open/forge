"""Shared runtime types, errors, logging, and artifact helpers."""

from __future__ import annotations

import json
import os
import tempfile
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

JsonObject = dict[str, Any]
Logger = Callable[[str], None]


class SplunkIntegrationError(RuntimeError):
    """Raised when a Splunk Data Manager lifecycle operation cannot continue."""


class SplunkHttpError(SplunkIntegrationError):
    """Raised for an unsuccessful Splunk HTTP request."""

    def __init__(self, status: int, message: str):
        super().__init__(message)
        self.status = status

    @property
    def retryable(self) -> bool:
        """Return whether an input fetch may be retried."""
        return self.status == 0 or self.status in {
            404,
            409,
            429,
        } or self.status >= 500


@dataclass(frozen=True, slots=True)
class HttpResponse:
    """Minimal HTTP response used by the Splunk client."""

    status: int
    body: bytes


@dataclass(frozen=True, slots=True)
class RuntimeConfig:
    """Runtime values supplied by Terraform."""

    cloud_url: str
    input_id: str
    username: str = field(repr=False)
    password: str = field(repr=False)
    input_request: JsonObject | None = field(default=None, repr=False)


@dataclass(frozen=True, slots=True)
class ArtifactPaths:
    """Local artifacts consumed by the Terraform module."""

    input_json: Path
    template_json: Path
    log: Path

    @classmethod
    def for_input(
        cls,
        input_id: str,
        *,
        artifact_dir: Path = Path('/tmp'),
    ) -> ArtifactPaths:
        """Build the established artifact paths for an input."""
        return cls(
            input_json=artifact_dir / f'{input_id}_input.json',
            template_json=artifact_dir / f'{input_id}_template.json',
            log=artifact_dir / f'{input_id}_logs.txt',
        )


class FileLogger:
    """Append lifecycle diagnostics to the input-specific log file."""

    def __init__(self, path: Path):
        self.path = path

    def __call__(self, message: str) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open('a', encoding='utf-8') as log:
            log.write(f'{message}\n')


def encode_json(payload: JsonObject) -> bytes:
    """Encode a compact JSON object for Splunk or an artifact file."""
    return json.dumps(payload, separators=(',', ':')).encode('utf-8')


def decode_json(raw: bytes, description: str) -> JsonObject:
    """Decode a Splunk response and require a JSON object."""
    try:
        document = json.loads(raw)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SplunkIntegrationError(
            f'Splunk returned an invalid {description}'
        ) from error
    if not isinstance(document, dict):
        raise SplunkIntegrationError(
            f'Splunk returned a non-object {description}'
        )
    return document


def atomic_write(path: Path, content: bytes) -> None:
    """Atomically replace an artifact in its destination directory."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            dir=path.parent,
            prefix=f'.{path.name}.',
            delete=False,
        ) as temporary:
            temporary.write(content)
            temporary_path = Path(temporary.name)
        os.replace(temporary_path, path)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
