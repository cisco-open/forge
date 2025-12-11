import base64  # noqa: E402
import json  # noqa: E402
import logging  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import sys  # noqa: E402
import time  # noqa: E402
from typing import Any, Dict, Tuple  # noqa: E402

# Add the 'package' directory to sys.path so that Python knows to look there for dependencies
package_dir = os.path.join(os.path.dirname(__file__), 'package')
if package_dir not in sys.path:
    sys.path.append(package_dir)

import boto3  # noqa: E402
import jwt  # noqa: E402
import requests  # noqa: E402

# Configure logging
LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

DYNAMODB_TABLE = os.getenv('DYNAMODB_TABLE')

SSM = boto3.client('ssm')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)


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


def get_secret(secret_name: str) -> str:
    """Retrieve secrets from AWS Systems Manager Parameter Store."""
    response = SSM.get_parameter(Name=secret_name, WithDecryption=True)
    return response['Parameter']['Value']


def parse_github_url(workflow_run_url: str) -> Tuple[str, str, str]:
    match = re.search(
        r'github.com/([^/]+)/([^/]+)/actions/runs/(\d+)', workflow_run_url)
    if match:
        owner, repo, run_id = match.groups()
        return owner, repo, run_id
    return None, None, None


def scan_and_process_dynamodb(access_token: str):
    last_evaluated_key = None

    while True:
        scan_kwargs = {}
        if last_evaluated_key:
            scan_kwargs['ExclusiveStartKey'] = last_evaluated_key

        response = table.scan(**scan_kwargs)
        items = response.get('Items', [])

        for item in items:
            workflow_run_url = item.get('workflow_run_url')
            workflow_run_attempt = item.get('workflow_run_attempt')
            lock_id = item.get('lock_id')
            item.get('workflow_run_id')

            if not workflow_run_url:
                continue

            owner, repo, run_id = parse_github_url(workflow_run_url)
            if not owner or not repo or not run_id:
                continue

            status = get_workflow_status(
                access_token, owner, repo, run_id, workflow_run_attempt)
            if status == 'completed':
                print(f'Deleting completed workflow: {workflow_run_url}')
                table.delete_item(
                    Key={'lock_id': lock_id})

        last_evaluated_key = response.get('LastEvaluatedKey')
        if not last_evaluated_key:
            break


def get_workflow_status(access_token: str, owner: str, repo: str, run_id: str, attempt_number: str) -> str:
    url = f'https://api.github.com/repos/{owner}/{repo}/actions/runs/{run_id}/attempts/{attempt_number}'
    headers = {'Authorization': f'token {access_token}',
               'Accept': 'application/vnd.github.v3+json'}

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        return response.json().get('status')  # "completed" or other statuses
    return None


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """AWS Lambda entry point."""
    try:
        # Fetch secrets from Secrets Manager
        secret_name_app_id = os.getenv('SECRET_NAME_APP_ID')
        secret_name_private_key = os.getenv('SECRET_NAME_PRIVATE_KEY')
        secret_name_installation_id = os.getenv('SECRET_NAME_INSTALLATION_ID')
        os.getenv('AWS_REGION')

        LOG.info('Fetching secrets from AWS Secrets Manager')
        app_id = get_secret(secret_name_app_id)
        private_key = base64.b64decode(get_secret(
            secret_name_private_key)).decode('utf-8')
        installation_id = get_secret(secret_name_installation_id)

        # Generate JWT
        LOG.info('Generating JWT')
        private_key = private_key.replace('\\n', '\n')
        jwt_token = generate_jwt(app_id, private_key)

        # Get installation access token
        LOG.info('Getting installation access token')
        access_token = get_installation_access_token(
            jwt_token, installation_id)

        scan_and_process_dynamodb(access_token)

        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Cleaned lock successfully.'})
        }
    except Exception as e:
        LOG.exception(
            f'Unhandled exception in github_global_lock lambda. Error: {str(e)}')
        raise
