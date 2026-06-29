"""Lambda execution smoke test (opt-in).

Proves MiniStack's headline feature: it really runs a Python lambda, not a mock.
This is the stepping stone to the real layer-mounted handler test later.

Marked `lambda_exec` and excluded from the default `-m smoke` run because it
needs Docker (MiniStack spawns a container per function) and is slower. Run with:
    pytest -m lambda_exec
"""

from __future__ import annotations

import io
import json
import time
import zipfile

import pytest
from botocore.exceptions import ClientError

pytestmark = pytest.mark.lambda_exec

HANDLER_SRC = (
    'def handle(event, context):\n'
    "    return {'echo': event, 'ok': True}\n"
)


def _zip(src: str) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w') as z:
        z.writestr('handler.py', src)
    return buf.getvalue()


def test_lambda_executes_python(client):
    lam = client('lambda')
    name = 'forge-smoke-echo'
    try:
        lam.create_function(
            FunctionName=name,
            Runtime='python3.12',
            Role='arn:aws:iam::000000000000:role/forge-smoke-lambda',
            Handler='handler.handle',
            Code={'ZipFile': _zip(HANDLER_SRC)},
            Timeout=30,
        )
    except ClientError as e:
        if e.response['Error']['Code'] != 'ResourceConflictException':
            raise  # already created on a prior run

    # Wait for the function to become invokable.
    for _ in range(30):
        state = lam.get_function(FunctionName=name)[
            'Configuration'].get('State')
        if state in (None, 'Active'):
            break
        time.sleep(1)

    resp = lam.invoke(FunctionName=name, Payload=json.dumps(
        {'hello': 'forge'}).encode())
    assert resp['StatusCode'] == 200
    payload = json.loads(resp['Payload'].read())
    assert payload['ok'] is True
    assert payload['echo'] == {'hello': 'forge'}
