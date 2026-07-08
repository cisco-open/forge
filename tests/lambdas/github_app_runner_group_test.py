"""GitHub App runner-group reconciliation Lambda tests."""

from __future__ import annotations

import base64
import json

import pytest
from botocore.exceptions import ClientError
from conftest import requires_aws
from support import load_handler_module

pytestmark = requires_aws


class _Response:
    def __init__(self, payload, *, links=None, headers=None):
        self._payload = payload
        self.links = links or {}
        self.headers = headers or {}

    def json(self):
        return self._payload

    def raise_for_status(self):
        return None


def test_list_repositories_follows_github_pagination(monkeypatch, aws):
    mod = load_handler_module('github_app_runner_group')
    calls = []

    def _get(url, headers):
        calls.append((url, headers))
        if len(calls) == 1:
            return _Response(
                {'repositories': [{'id': 1, 'full_name': 'org/one'}]},
                links={'next': {'url': 'https://api.github.test/page/2'}},
            )
        return _Response(
            {'repositories': [{'id': 2, 'full_name': 'org/two'}]},
        )

    monkeypatch.setattr(mod.requests, 'get', _get)

    repos = mod.list_repositories('token-123', 'https://api.github.test')

    assert [repo['full_name'] for repo in repos] == ['org/one', 'org/two']
    assert calls[0][0] == 'https://api.github.test/installation/repositories'
    assert calls[1][0] == 'https://api.github.test/page/2'


def test_save_to_runner_group_creates_selected_group_and_adds_repos(
    monkeypatch, aws
):
    mod = load_handler_module('github_app_runner_group')
    calls = []
    monkeypatch.setattr(mod, 'get_all_runner_groups', lambda *_args: [])

    def _post(url, json, headers):
        calls.append(('post', url, json, headers))
        return _Response({'id': 123, 'name': 'forge-small'})

    def _put(url, headers):
        calls.append(('put', url, None, headers))
        return _Response({})

    monkeypatch.setattr(mod.requests, 'post', _post)
    monkeypatch.setattr(mod.requests, 'put', _put)

    mod.save_to_runner_group(
        'token-123',
        'https://api.github.test',
        'acme',
        'forge-small',
        [{'id': 10, 'full_name': 'acme/app'}],
        'selected',
    )

    assert calls[0][0] == 'post'
    assert calls[0][1] == (
        'https://api.github.test/orgs/acme/actions/runner-groups'
    )
    assert calls[0][2] == {
        'name': 'forge-small',
        'visibility': 'selected',
        'selected_repository_ids': [],
    }
    assert calls[1][0] == 'put'
    assert calls[1][1].endswith('/runner-groups/123/repositories/10')


def test_save_to_runner_group_updates_all_visibility_without_repo_puts(
    monkeypatch, aws
):
    mod = load_handler_module('github_app_runner_group')
    patch_calls = []
    monkeypatch.setattr(
        mod,
        'get_all_runner_groups',
        lambda *_args: [{'id': 123, 'name': 'forge-small'}],
    )

    def _patch(url, json, headers):
        patch_calls.append((url, json, headers))
        return _Response({})

    monkeypatch.setattr(mod.requests, 'patch', _patch)
    monkeypatch.setattr(
        mod.requests,
        'put',
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError('visibility=all must not add repositories')
        ),
    )

    mod.save_to_runner_group(
        'token-123',
        'https://api.github.test',
        'acme',
        'forge-small',
        [{'id': 10, 'full_name': 'acme/app'}],
        'all',
    )

    assert len(patch_calls) == 1
    assert patch_calls[0][0].endswith('/runner-groups/123')
    assert patch_calls[0][1] == {'visibility': 'all'}


def test_get_all_runner_groups_follows_link_header_pagination(
    monkeypatch, aws
):
    mod = load_handler_module('github_app_runner_group')
    calls = []

    def _get(url, headers):
        calls.append((url, headers))
        if len(calls) == 1:
            return _Response(
                {'runner_groups': [{'id': 1, 'name': 'small'}]},
                headers={
                    'link': (
                        '<https://api.github.test/page/2>; rel="next"'
                    ),
                },
            )
        return _Response(
            {'runner_groups': [{'id': 2, 'name': 'large'}]},
            headers={},
        )

    monkeypatch.setattr(mod.requests, 'get', _get)

    groups = mod.get_all_runner_groups(
        'https://api.github.test/orgs/acme/actions/runner-groups',
        {'Authorization': 'Bearer token'},
    )

    assert [group['name'] for group in groups] == ['small', 'large']
    assert calls[1][0] == 'https://api.github.test/page/2'


def test_lambda_handler_propagates_missing_secret_without_github_calls(
    monkeypatch, ssm
):
    mod = load_handler_module('github_app_runner_group')
    for key, value in {
        'SECRET_NAME_APP_ID': '/forge/missing-app-id',
        'SECRET_NAME_PRIVATE_KEY': '/forge/missing-private-key',
        'SECRET_NAME_INSTALLATION_ID': '/forge/missing-installation-id',
        'REPOSITORY_SELECTION': 'selected',
        'ORGANIZATION': 'acme',
        'GITHUB_API': 'https://api.github.test',
        'RUNNER_GROUP_NAME': 'forge-small',
    }.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setattr(
        mod,
        'generate_jwt',
        lambda *_args, **_kwargs: (_ for _ in ()).throw(
            AssertionError('missing SSM secret must stop before GitHub auth')
        ),
    )

    with pytest.raises(ClientError) as exc:
        mod.lambda_handler({}, None)

    assert exc.value.response['Error']['Code'] == 'ParameterNotFound'


def test_lambda_handler_uses_ssm_secrets_and_selected_repos(
    monkeypatch, ssm
):
    mod = load_handler_module('github_app_runner_group')
    client = ssm['client']
    for name, value in {
        '/forge/app_id': '12345',
        '/forge/private_key': base64.b64encode(b'FAKE-KEY').decode(),
        '/forge/installation_id': '999',
    }.items():
        client.put_parameter(Name=name, Value=value, Type='SecureString')

    for key, value in {
        'SECRET_NAME_APP_ID': '/forge/app_id',
        'SECRET_NAME_PRIVATE_KEY': '/forge/private_key',
        'SECRET_NAME_INSTALLATION_ID': '/forge/installation_id',
        'REPOSITORY_SELECTION': 'selected',
        'ORGANIZATION': 'acme',
        'GITHUB_API': 'https://api.github.test',
        'RUNNER_GROUP_NAME': 'forge-small',
    }.items():
        monkeypatch.setenv(key, value)

    saved = {}
    monkeypatch.setattr(mod, 'generate_jwt', lambda app_id, key: 'jwt-token')
    monkeypatch.setattr(
        mod,
        'get_installation_access_token',
        lambda jwt_token, installation_id, github_api: 'installation-token',
    )
    monkeypatch.setattr(
        mod,
        'list_repositories',
        lambda token, api: [{'id': 10, 'full_name': 'acme/app'}],
    )

    def _save(token, api, org, group, repos, visibility):
        saved.update({
            'token': token,
            'api': api,
            'org': org,
            'group': group,
            'repos': repos,
            'visibility': visibility,
        })

    monkeypatch.setattr(mod, 'save_to_runner_group', _save)

    result = mod.lambda_handler({}, None)

    assert result['statusCode'] == 200
    assert json.loads(result['body']) == {
        'message': 'Repositories added to runner group successfully.'
    }
    assert saved == {
        'token': 'installation-token',
        'api': 'https://api.github.test',
        'org': 'acme',
        'group': 'forge-small',
        'repos': [{'id': 10, 'full_name': 'acme/app'}],
        'visibility': 'selected',
    }
