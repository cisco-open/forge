# -*- coding: utf-8 -*-
import base64  # noqa: E402
import json  # noqa: E402
import logging  # noqa: E402
import os  # noqa: E402
import sys  # noqa: E402
import time  # noqa: E402
from typing import Any, Dict, List  # noqa: E402

# Add the 'package' directory to sys.path so that Python knows to look there for dependencies
package_dir = os.path.join(os.path.dirname(__file__), 'package')
if package_dir not in sys.path:
    sys.path.append(package_dir)

import boto3  # noqa: E402
import jwt  # noqa: E402
import requests  # noqa: E402

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger()


def generate_jwt(app_id: str, private_key: str) -> str:
    """Generate a JWT for GitHub App authentication."""
    payload = {
        'iat': int(time.time()),
        'exp': int(time.time()) + (10 * 60),
        'iss': app_id,
    }
    return jwt.encode(payload, private_key, algorithm='RS256')


def get_installation_access_token(jwt_token: str, installation_id: str) -> str:
    """Fetch an access token for the installation."""
    headers = {
        'Authorization': f'Bearer {jwt_token}',
        'Accept': 'application/vnd.github+json',
    }
    url = f'https://api.github.com/app/installations/{installation_id}/access_tokens'
    response = requests.post(url, headers=headers)
    response.raise_for_status()
    return response.json()['token']


def list_repositories(access_token: str) -> List[Dict[str, Any]]:
    """List all repositories the GitHub App has access to."""
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/vnd.github+json',
    }

    repos = []
    url = 'https://api.github.com/installation/repositories'

    while url:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()

        # Add repositories from the current page
        repos.extend(data['repositories'])

        # Get the 'next' URL from the Link header to fetch the next page of results
        url = response.links.get('next', {}).get('url', None)

    return repos


def get_all_runner_groups(url: str, headers: Dict[str, str]) -> List[Dict[str, Any]]:
    """Fetch all runner groups, handling pagination."""
    runner_groups = []
    while url:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()
        runner_groups.extend(data.get('runner_groups', []))

        # Check for pagination in the 'Link' header
        if 'link' in response.headers:
            links = response.headers['link']
            next_link = None
            for link in links.split(','):
                if 'rel="next"' in link:
                    next_link = link[link.find('<') + 1:link.find('>')]
            url = next_link
        else:
            url = None

    return runner_groups


def create_runner_group(access_token: str, organization: str, runner_group_name: str) -> Dict[str, Any]:
    """Create a new runner group in the GitHub organization."""
    url = f'https://api.github.com/orgs/{organization}/actions/runner-groups'
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/vnd.github+json',
    }
    payload = {
        'name': runner_group_name,
        'visibility': 'selected',
        'selected_repository_ids': []
    }
    response = requests.post(url, json=payload, headers=headers)
    response.raise_for_status()
    logger.info(
        f"Created runner group '{runner_group_name}' in org '{organization}'.")
    return response.json()


def save_to_runner_group(access_token: str, organization: str, runner_group_name: str, repos: List[Dict[str, Any]]):
    """Add repositories to a GitHub Runner Group."""
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Accept': 'application/vnd.github+json',
    }

    url = f'https://api.github.com/orgs/{organization}/actions/runner-groups'

    # Get all runner groups
    groups = get_all_runner_groups(url, headers)

    # Find the Runner Group ID
    group_id = next((g['id']
                    for g in groups if g['name'] == runner_group_name), None)
    if not group_id:
        group = create_runner_group(
            access_token, organization, runner_group_name)
        group_id = group['id']

    # Add Repositories to the Runner Group
    for repo in repos:
        repo_id = repo['id']
        add_url = f'https://api.github.com/orgs/{organization}/actions/runner-groups/{group_id}/repositories/{repo_id}'
        response = requests.put(add_url, headers=headers)
        response.raise_for_status()
        logger.info(
            f"Added repository {repo['full_name']} to runner group {runner_group_name}.")


def get_secret(secret_name: str) -> Dict[str, Any]:
    """Retrieve secrets from AWS Secrets Manager."""
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId=secret_name)
    return response['SecretString']


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """AWS Lambda entry point."""
    try:
        # Fetch secrets from Secrets Manager
        secret_name_app_id = os.getenv('SECRET_NAME_APP_ID')
        secret_name_private_key = os.getenv('SECRET_NAME_PRIVATE_KEY')
        secret_name_installation_id = os.getenv('SECRET_NAME_INSTALLATION_ID')
        os.getenv('AWS_REGION')

        logger.info('Fetching secrets from AWS Secrets Manager')
        app_id = get_secret(secret_name_app_id)
        private_key = base64.b64decode(get_secret(
            secret_name_private_key)).decode('utf-8')
        installation_id = get_secret(secret_name_installation_id)
        organization = os.getenv('ORGANIZATION')
        runner_group_name = os.getenv('RUNNER_GROUP_NAME')

        # Generate JWT
        logger.info('Generating JWT')
        private_key = private_key.replace('\\n', '\n')
        jwt_token = generate_jwt(app_id, private_key)

        # Get installation access token
        logger.info('Getting installation access token')
        access_token = get_installation_access_token(
            jwt_token, installation_id)

        # List repositories
        logger.info('Listing repositories')
        repos = list_repositories(access_token)

        # Save to Runner Group
        logger.info('Saving repositories to runner group')
        save_to_runner_group(access_token, organization,
                             runner_group_name, repos)

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Repositories added to runner group successfully.'})
        }
    except Exception as e:
        logger.error(f'Error: {str(e)}')
        return {
            'statusCode': 500,
            'body': json.dumps({'message': 'An error occurred', 'error': str(e)})
        }
