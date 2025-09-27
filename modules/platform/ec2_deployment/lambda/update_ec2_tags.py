import json
import logging

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client('ssm')
ec2 = boto3.client('ec2')


def lambda_handler(event, context):
    logger.info('Received event: %s', json.dumps(event))

    if event.get('detail-type') != 'workflow_job':
        logger.info('Ignoring non-workflow_job event: %s',
                    event.get('detail-type'))
        return {'statusCode': 200, 'body': json.dumps({'message': 'ignored event'})}

    detail = event.get('detail', {})
    logger.debug('Event detail payload: %s', json.dumps(detail))

    runner_name = detail.get('workflow_job').get('runner_name')
    if not runner_name:
        logger.error('runner_name missing in event detail: %s', detail)
        return {'statusCode': 400, 'body': json.dumps({'error': 'runner_name missing'})}

    logger.info('Looking up EC2 instances with Name tag: %s', runner_name)
    resp = ec2.describe_instances(
        Filters=[{'Name': 'tag:Name', 'Values': [runner_name]}])
    instance_ids = [
        inst['InstanceId']
        for res in resp.get('Reservations', [])
        for inst in res.get('Instances', [])
    ]
    logger.info('Described instances, found IDs: %s', instance_ids)
    if not instance_ids:
        logger.info('No instances found with Name tag %s', runner_name)
        return {'statusCode': 200, 'body': json.dumps({'message': 'no instances found'})}

    logger.info("Tagging instances %s with tag 'found':'1'", instance_ids)
    ec2.create_tags(Resources=instance_ids, Tags=[
                    {'Key': 'found', 'Value': '1'}])
    logger.info('Successfully tagged instances: %s', instance_ids)
    return {'statusCode': 200, 'body': json.dumps({'tagged_instances': instance_ids})}
