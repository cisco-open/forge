"""STS trust-validator policy logic (register A2, P0-7, P1-13).

Target: .../forge_runners/forge_trust_validator/lambda/trust_common.py

The validator temporarily edits forge-role trust policies and assumes roles
with a restrictive session policy. The pure policy-construction helpers are the
isolation-critical, deterministic core — tested here without AWS calls:

  * the session policy restricts the forge session to sts:AssumeRole/TagSession
    on EXACTLY the tenant role ARNs passed in (no wildcard, no broadening);
  * the temporary trust statement targets only the validator lambda's own role;
  * stale validator statements are removed idempotently (so a crashed run can't
    leave a standing assume path — P1-13).

These assert intended invariants; they are NOT marked xfail because the current
logic is believed correct — they lock it against regression.
"""

from __future__ import annotations

import json

import pytest
from conftest import requires_aws
from support import load_handler_module

pytestmark = [pytest.mark.isolation, requires_aws]

LAMBDA_ROLE = 'arn:aws:iam::123456789012:role/forge-trust-validator'
TENANT_A = 'arn:aws:iam::111111111111:role/tenant-a'
TENANT_B = 'arn:aws:iam::222222222222:role/tenant-b'


def _tc():
    return load_handler_module('trust_common')


def test_session_policy_scopes_to_exact_tenant_arns():
    tc = _tc()
    policy = json.loads(
        tc.build_session_policy_for_tenants([TENANT_A, TENANT_B]))
    stmt = policy['Statement'][0]
    assert stmt['Effect'] == 'Allow'
    assert set(stmt['Action']) == {'sts:AssumeRole', 'sts:TagSession'}
    # Resource is exactly the tenant ARNs — no wildcard, no extras.
    assert stmt['Resource'] == [TENANT_A, TENANT_B]
    assert '*' not in json.dumps(stmt['Resource'])


def test_temporary_trust_statement_targets_only_validator_role():
    tc = _tc()
    stmt = tc.build_lambda_trust_statement(LAMBDA_ROLE)
    assert stmt['Effect'] == 'Allow'
    assert stmt['Action'] == 'sts:AssumeRole'
    assert stmt['Principal']['AWS'] == LAMBDA_ROLE
    assert stmt['Sid'] == tc.TRUST_STATEMENT_SID


def test_build_temporary_trust_adds_exactly_one_validator_statement():
    tc = _tc()
    base = {
        'Version': '2012-10-17',
        'Statement': [
            {
                'Effect': 'Allow',
                'Principal': {'Service': 'lambda.amazonaws.com'},
                'Action': 'sts:AssumeRole',
            }
        ],
    }
    out = tc.build_temporary_forge_trust_policy(base, LAMBDA_ROLE)
    validator_stmts = [
        s for s in out['Statement'] if s.get('Sid') == tc.TRUST_STATEMENT_SID
    ]
    assert len(validator_stmts) == 1
    # Original (service-principal) statement is preserved.
    assert any(
        s.get('Principal', {}).get('Service') == 'lambda.amazonaws.com'
        for s in out['Statement']
    )


def test_stale_validator_statements_removed_idempotently():
    tc = _tc()
    # A policy that already carries two stale validator statements.
    base = {
        'Version': '2012-10-17',
        'Statement': [
            {'Effect': 'Allow', 'Principal': {'Service': 'lambda.amazonaws.com'},
             'Action': 'sts:AssumeRole'},
            tc.build_lambda_trust_statement(LAMBDA_ROLE),
            tc.build_lambda_trust_statement(LAMBDA_ROLE),
        ],
    }
    cleaned = tc.remove_validator_trust_statement(base)
    assert not tc.policy_has_validator_statement(cleaned)
    # Re-running is a no-op (idempotent) — a crashed run can be swept safely.
    cleaned2 = tc.remove_validator_trust_statement(cleaned)
    assert cleaned2['Statement'] == cleaned['Statement']


def test_normalize_rejects_non_object_policy():
    tc = _tc()
    with pytest.raises(Exception):
        tc.normalize_policy_document('[]')
