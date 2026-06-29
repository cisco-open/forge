"""Dependency/import parity (register A4, P1-16).

ForgeMT does NOT build its own Lambda Layer. Runtime third-party deps come from
public Klayers layers (account 770693421928): cryptography, requests, PyJWT,
pinned by ARN version (job_log_archiver.tf:21-24, github_global_lock/main.tf:93-96).

These tests catch the classic "passes for the wrong reason" failure: a handler
that imports a dep the runtime won't actually have. They assert:
  * the Klayers-provided deps are importable (tests must install the same set —
    tests/requirements-dev.txt);
  * each first-party handler module imports cleanly (no syntax/dep surprise).
"""

from __future__ import annotations

import importlib

import pytest
from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws

# Provided by Klayers in production; must be present for archiver/runner-group/
# global-lock to import as the runtime does.
KLAYERS_PROVIDED = ['cryptography', 'requests', 'jwt']


@pytest.mark.parametrize('dep', KLAYERS_PROVIDED)
def test_klayers_provided_dep_is_importable(dep):
    assert importlib.import_module(dep)


@pytest.mark.parametrize(
    'module_name',
    [
        'validate_signature',
        'job_log_dispatcher',
        'job_log_archiver',
        'redrive_deadletter',
        'trust_common',
        'trust_preparer',
        'trust_validator',
    ],
)
def test_handler_module_imports(module_name, monkeypatch, aws):
    # Some modules read required env at import; provide harmless placeholders so
    # the import itself (not config) is what's under test.
    for var in (
        'EVENT_BUS',
        'QUEUE_URL',
        'DYNAMODB_TABLE',
        'BUCKET_NAME',
        'KMS_KEY_ARN',
        'GITHUB_API',
        'SQS_MAP',
    ):
        monkeypatch.setenv(var, 'placeholder')
    assert load_handler_module(module_name) is not None
