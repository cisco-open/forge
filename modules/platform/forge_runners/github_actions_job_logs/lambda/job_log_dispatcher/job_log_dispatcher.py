import json
import logging
import os

import boto3

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

sqs = boto3.client('sqs')

REPO_TENANT = json.loads(os.environ.get('REPO_TENANT_JSON', '{}'))
QUEUE_URL = os.environ['QUEUE_URL']


def lambda_handler(event, context):
    LOG.debug('Received event')

    if event.get('detail-type') != 'workflow_job':
        LOG.info('Ignoring non-workflow_job event: %s',
                 event.get('detail-type'))
        return {'statusCode': 200, 'body': json.dumps({'message': 'ignored event'})}
    sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(event))

    detail = event.get('detail', {})
    workflow_job = detail.get('workflow_job', {})
    repo = detail.get('repository', {}).get('full_name')

    payload = {
        'repository': repo,
        'job_id': workflow_job.get('id'),
        'run_id': workflow_job.get('run_id'),
        'workflow': workflow_job.get('workflow_name'),
        'attempt': workflow_job.get('run_attempt', 1),
        'job_name': workflow_job.get('name'),
        'status': workflow_job.get('status'),
        'conclusion': workflow_job.get('conclusion'),
        'branch': workflow_job.get('head_branch'),
        'sha': (workflow_job.get('head_sha') or '')[:12],
        'labels': workflow_job.get('labels', []),
        'action': detail.get('action'),
    }

    LOG.info(
        'Enqueued workflow_job action=%s repo=%s job_id=%s run_id=%s workflow=%s job_name=%s status=%s conclusion=%s attempt=%s branch=%s sha=%s labels=%s',
        payload['action'], payload['repository'], payload['job_id'], payload['run_id'],
        payload['workflow'], payload['job_name'], payload['status'], payload['conclusion'],
        payload['attempt'], payload['branch'], payload['sha'], ','.join(
            payload['labels'])
    )

    return {'enqueued': True}
