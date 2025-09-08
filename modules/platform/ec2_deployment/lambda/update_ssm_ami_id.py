import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

ssm = boto3.client('ssm')
ec2 = boto3.client('ec2')


def lambda_handler(event, context):
    runner_map = json.loads(os.environ.get('RUNNER_AMI_MAP', '{}'))

    for runner_key, info in runner_map.items():
        ssm_id = info['ssm_id']
        ami_filters = info['ami_filter']
        ami_owners = info['ami_owners']

        filters = [{'Name': k, 'Values': v} for k, v in ami_filters.items()]

        images = ec2.describe_images(
            Owners=ami_owners,
            Filters=filters
        ).get('Images', [])

        if not images:
            logger.warning('No AMIs found for runner %s', runner_key)
            continue

        latest_ami = sorted(
            images, key=lambda x: x['CreationDate'], reverse=True)[0]
        new_ami_id = latest_ami['ImageId']

        try:
            current_ssm = ssm.get_parameter(Name=ssm_id)['Parameter']['Value']
        except ssm.exceptions.ParameterNotFound as e:
            logger.error('SSM parameter not found: %s', ssm_id)
            raise RuntimeError(f'SSM parameter not found: {ssm_id}') from e

        if current_ssm != new_ami_id:
            ssm.put_parameter(
                Name=ssm_id,
                Value=new_ami_id,
                Type='String',
                Overwrite=True
            )
            logger.info('Updated %s to %s', ssm_id, new_ami_id)

            ssm.add_tags_to_resource(
                ResourceType='Parameter',
                ResourceId=ssm_id,
                Tags=[
                    {'Key': 'ghr:ami_name', 'Value': latest_ami['Name']},
                    {'Key': 'ghr:ami_creation_date',
                        'Value': latest_ami['CreationDate']},
                ]
            )
        else:
            logger.info('SSM parameter %s already up-to-date (%s)',
                        ssm_id, current_ssm)

    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'AMI SSM update process completed'})
    }
