import json
import logging

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client('ssm')
ec2 = boto3.client('ec2')


def lambda_handler(event, context):
    logger.debug('Received event')

    if event.get('detail-type') != 'workflow_job':
        logger.info('Ignoring non-workflow_job event: %s',
                    event.get('detail-type'))
        return {'statusCode': 200, 'body': json.dumps({'message': 'ignored event'})}

    detail = event.get('detail', {})

    runner_name = detail.get('workflow_job').get('runner_name')
    if not runner_name:
        logger.error('runner_name missing in event detail: %s', detail)
        return {'statusCode': 400, 'body': json.dumps({'error': 'runner_name missing'})}

    if not (isinstance(runner_name, str) and runner_name.startswith('i-')):
        logger.info(
            'Runner name %s is not an EC2 instance ID, ignoring', runner_name)
        return {'statusCode': 200, 'body': json.dumps({'message': 'ignored non-EC2 runner'})}

    logger.info('Looking up EC2 instance by ID: %s', runner_name)
    try:
        resp = ec2.describe_instances(InstanceIds=[runner_name])
        instance_ids = [inst['InstanceId'] for res in resp.get(
            'Reservations', []) for inst in res.get('Instances', [])]
    except ec2.exceptions.ClientError as e:
        logger.error('Error fetching instance %s: %s', runner_name, e)
        return {'statusCode': 500, 'body': json.dumps({'error': 'describe_instances failed'})}

    logger.info('Described instances, found IDs: %s', instance_ids)
    if not instance_ids:
        logger.info('No instances found with Name tag %s', runner_name)
        return {'statusCode': 200, 'body': json.dumps({'message': 'no instances found'})}

    job_url = detail.get('workflow_job', {}).get('html_url', '')
    job_id = str(detail.get('workflow_job', {}).get('id', ''))
    logger.info('GitHub job URL: %s, job ID: %s', job_url, job_id)

    # Tag instances with found flag and GitHub URLs
    logger.info(
        'Tagging instances %s with tags job_url, job_id', instance_ids)
    ec2.create_tags(Resources=instance_ids, Tags=[
        {'Key': 'ghr:job_id', 'Value': job_id},
        {'Key': 'ghr:job_url', 'Value': job_url}
    ])
    logger.info('Successfully tagged instances: %s', instance_ids)
    return {'statusCode': 200, 'body': json.dumps({'tagged_instances': instance_ids})}
