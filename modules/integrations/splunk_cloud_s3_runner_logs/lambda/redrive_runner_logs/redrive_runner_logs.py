import logging
import os

import boto3

LOG = logging.getLogger()
level_str = os.environ.get('LOG_LEVEL', 'INFO').upper()
LOG.setLevel(getattr(logging, level_str, logging.INFO))

sqs = boto3.client('sqs')


def lambda_handler(event, _context):
    if event.get('healthcheck'):
        LOG.info('runner_logs_redrive_healthcheck')
        return {'status': 'healthy'}

    dlq_arn = os.environ['DLQ_ARN']
    LOG.info('runner_logs_redrive_start dlq=%s', dlq_arn)

    response = sqs.start_message_move_task(SourceArn=dlq_arn)
    task_handle = response.get('TaskHandle')

    LOG.info(
        'runner_logs_redrive_started dlq=%s task_handle=%s',
        dlq_arn,
        task_handle,
    )
    return {
        'status': 'started',
        'dlq': dlq_arn,
        'task_handle': task_handle,
    }
