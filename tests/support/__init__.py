"""Shared test support for ForgeMT first-party lambda unit tests.

Contains NO production logic. It provides:
  1. `repo_root()` + `lambda_dir()` — locate real handler source in-tree.
  2. `load_handler_module()` — import a real lambda module the way the runtime
     does (its own dir on sys.path; Klayers-provided deps imported from the
     venv, see register A4). Re-imports cleanly so module-level env reads
     (e.g. validate_signature.SECRET) reflect per-test env.
  3. GitHub webhook signing helpers (HMAC-SHA256 / legacy SHA-1).
  4. `make_apigw_v2_event()` — the REAL event shape: HTTP API Gateway v2 proxy
     (validate_signature is wired as an AWS_PROXY integration, register A0/A1).

Wiring note: unlike the original scaffold there is no "reference verifier"
fallback — these tests drive the real handlers. If a handler can't be imported
(missing dep), the relevant test is skipped with a clear reason rather than
silently testing a placeholder.
"""

from __future__ import annotations

import hashlib
import hmac
import importlib
import json
import sys
from pathlib import Path
from types import ModuleType


# --------------------------------------------------------------------------- #
# Locating real handler source
# --------------------------------------------------------------------------- #
def repo_root() -> Path:
    """Repo root = two levels up from this file (tests/support/__init__.py)."""
    return Path(__file__).resolve().parents[2]


# Map a handler module name -> its source directory, relative to repo root.
# These are the REAL paths verified in Phase 1 (register A1). The lambda dir
# itself is the import root at runtime (handler = "<module>.lambda_handler").
LAMBDA_DIRS: dict[str, str] = {
    'validate_signature': (
        'modules/integrations/github_webhook_relay_source/lambda'
    ),
    'job_log_dispatcher': (
        'modules/platform/forge_runners/github_actions_job_logs/lambda/'
        'job_log_dispatcher'
    ),
    'job_log_archiver': (
        'modules/platform/forge_runners/github_actions_job_logs/lambda/'
        'job_log_archiver'
    ),
    'redrive_deadletter': (
        'modules/platform/forge_runners/redrive_deadletter/lambda'
    ),
    'trust_common': (
        'modules/platform/forge_runners/forge_trust_validator/lambda'
    ),
    'trust_preparer': (
        'modules/platform/forge_runners/forge_trust_validator/lambda'
    ),
    'trust_validator': (
        'modules/platform/forge_runners/forge_trust_validator/lambda'
    ),
}


def lambda_dir(module_name: str) -> Path:
    try:
        rel = LAMBDA_DIRS[module_name]
    except KeyError as exc:
        raise KeyError(
            f"Unknown lambda module {module_name!r}; add it to "
            f"tests/support.LAMBDA_DIRS"
        ) from exc
    return repo_root() / rel


def load_handler_module(module_name: str) -> ModuleType:
    """Import (or re-import) a real lambda module by name.

    The module's own directory is placed first on sys.path so intra-lambda
    imports (e.g. trust_preparer importing trust_common) resolve exactly like
    the AWS runtime. Module-level code re-runs on each call, so env vars set by
    a test before calling are observed by module-level reads.
    """
    src = lambda_dir(module_name)
    src_str = str(src)
    if src_str not in sys.path:
        sys.path.insert(0, src_str)
    # Force a fresh import so module-level env reads reflect current os.environ.
    sys.modules.pop(module_name, None)
    return importlib.import_module(module_name)


# --------------------------------------------------------------------------- #
# GitHub webhook signing helpers
# --------------------------------------------------------------------------- #
def sign_sha256(secret: bytes, body: bytes) -> str:
    """Return the value GitHub puts in the X-Hub-Signature-256 header."""
    digest = hmac.new(secret, body, hashlib.sha256).hexdigest()
    return f"sha256={digest}"


def sign_sha1_legacy(secret: bytes, body: bytes) -> str:
    """Legacy X-Hub-Signature (SHA-1). Present ONLY so tests can assert it is
    rejected. The handler must require SHA-256 and never trust SHA-1 alone.
    """
    digest = hmac.new(secret, body, hashlib.sha1).hexdigest()
    return f"sha1={digest}"


def make_apigw_v2_event(
    body: bytes,
    signature_256: str | None,
    *,
    event: str = 'workflow_job',
    action: str = 'queued',
    lowercase_headers: bool = False,
) -> dict:
    """Build a real HTTP API Gateway v2 (payload format 2.0) proxy event.

    validate_signature is an AWS_PROXY integration on an aws_apigatewayv2_api
    (register A0). Note: payload format 2.0 lowercases header keys — the
    `lowercase_headers` switch lets a test pin the handler's header-case
    handling (register A5 item 5).
    """
    headers = {
        'x-github-event' if lowercase_headers else 'X-GitHub-Event': event,
        'content-type' if lowercase_headers else 'Content-Type':
            'application/json',
    }
    if signature_256 is not None:
        key = (
            'x-hub-signature-256' if lowercase_headers else 'X-Hub-Signature-256'
        )
        headers[key] = signature_256
    return {
        'version': '2.0',
        'routeKey': 'POST /webhook',
        'headers': headers,
        'body': body.decode('utf-8'),
        'isBase64Encoded': False,
        'requestContext': {'http': {'method': 'POST', 'path': '/webhook'}},
    }


def webhook_body(action: str = 'queued', repo: str = 'acme/app') -> bytes:
    return json.dumps(
        {'action': action, 'repository': {'full_name': repo}}
    ).encode()
