#!/usr/bin/env python3
"""Generate a GitHub App JWT and update its webhook configuration."""

from __future__ import annotations

import base64
import json
import os
import subprocess
import sys
import tempfile
import time
from collections.abc import Mapping
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


class WebhookUpdateError(RuntimeError):
    """Raised when the GitHub App webhook cannot be updated."""


def log(message: str, *, stream=sys.stdout) -> None:
    """Write a timestamped message without including credential values."""
    timestamp = time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
    print(f'[{timestamp}] {message}', file=stream, flush=True)


def _base64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b'=').decode('ascii')


def _sign(signing_input: bytes, private_key: str) -> bytes:
    key_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode='w', encoding='utf-8', prefix='forge-github-app-', delete=False
        ) as key_file:
            key_file.write(private_key)
            key_path = Path(key_file.name)
        key_path.chmod(0o600)

        result = subprocess.run(
            ['openssl', 'dgst', '-sha256', '-sign', str(key_path)],
            input=signing_input,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=True,
        )
        return result.stdout
    except FileNotFoundError as error:
        raise WebhookUpdateError(
            'openssl is required but was not found') from error
    except subprocess.CalledProcessError as error:
        detail = error.stderr.decode('utf-8', errors='replace').strip()
        message = 'JWT signature generation failed'
        if detail:
            message = f'{message}: {detail}'
        raise WebhookUpdateError(message) from error
    finally:
        if key_path is not None:
            key_path.unlink(missing_ok=True)


def generate_jwt(client_id: str, private_key: str, *, now: int | None = None) -> str:
    """Create a ten-minute RS256 GitHub App JWT."""
    issued_at = int(time.time()) if now is None else now
    payload = {
        'iat': issued_at - 60,
        'exp': issued_at + 600,
        'iss': client_id,
    }
    header = {'typ': 'JWT', 'alg': 'RS256'}

    encoded_header = _base64url(
        json.dumps(header, separators=(',', ':')).encode('utf-8')
    )
    encoded_payload = _base64url(
        json.dumps(payload, separators=(',', ':')).encode('utf-8')
    )
    signing_input = f'{encoded_header}.{encoded_payload}'.encode('ascii')
    signature = _sign(signing_input, private_key)
    if not signature:
        raise WebhookUpdateError('JWT signature generation returned no data')

    return f'{signing_input.decode("ascii")}.{_base64url(signature)}'


def patch_github_webhook(
    *,
    jwt: str,
    github_api: str,
    webhook_url: str,
    secret: str,
    prefix: str,
    debug: bool,
    response_dir: Path = Path('/tmp'),
    opener=None,
) -> None:
    """Patch the GitHub App webhook and raise on a non-success response."""
    request_body = json.dumps(
        {
            'url': webhook_url,
            'content_type': 'json',
            'insecure_ssl': '0',
            'secret': secret,
        }
    ).encode('utf-8')
    endpoint = f'{github_api.rstrip("/")}/app/hook/config'
    request = Request(
        endpoint,
        data=request_body,
        method='PATCH',
        headers={
            'Authorization': f'Bearer {jwt}',
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
        },
    )

    log(f'PATCH {endpoint}')
    open_request = urlopen if opener is None else opener
    try:
        response = open_request(request)
        with response:
            status = response.status
            headers = response.headers
            body = response.read()
    except HTTPError as error:
        status = error.code
        headers = error.headers
        body = error.read()

    log(f'HTTP status={status}')
    if debug:
        log('Response headers:')
        for name, value in headers.items():
            log(f'  {name}: {value}')

    response_path = response_dir / f'{prefix}-github_api_response.log'
    response_path.write_bytes(body)
    log(f'Response body saved to {response_path} (size {len(body)} bytes)')

    if not 200 <= status < 300:
        raise WebhookUpdateError(
            f'GitHub webhook update failed with HTTP status {status}; '
            f'see {response_path}'
        )
    log('Success')


def _required_environment(environ: Mapping[str, str], name: str) -> str:
    value = environ.get(name)
    if not value:
        raise WebhookUpdateError(
            f'required environment variable {name} is not set')
    return value


def main(environ: Mapping[str, str] | None = None) -> None:
    """Load configuration, generate the JWT, and patch the webhook."""
    environment = os.environ if environ is None else environ
    client_id = _required_environment(environment, 'CLIENT_ID')
    private_key = _required_environment(environment, 'PRIVATE_KEY')
    github_api = _required_environment(environment, 'GITHUB_API')
    webhook_url = _required_environment(environment, 'WEBHOOK_URL')
    secret = _required_environment(environment, 'SECRET')
    prefix = _required_environment(environment, 'PREFIX')
    debug = environment.get('DEBUG', 'true').lower() == 'true'

    if debug:
        log('Debug enabled')
        log(f'CLIENT_ID (len) = {len(client_id)}')
        log(f'PRIVATE_KEY (len) = {len(private_key)}')
        log(f'GITHUB_API={github_api}')
        log(f'WEBHOOK_URL={webhook_url}')
        log(f'SECRET (len) = {len(secret)}')

    jwt = generate_jwt(client_id, private_key)
    log(f'JWT constructed (len)={len(jwt)}')
    patch_github_webhook(
        jwt=jwt,
        github_api=github_api,
        webhook_url=webhook_url,
        secret=secret,
        prefix=prefix,
        debug=debug,
    )


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        log(f'ERROR: {error}', stream=sys.stderr)
        raise SystemExit(1) from error
