"""Offline Terraform/Python contract tests for critical ForgeMT wiring.

These tests intentionally avoid `tofu init`, providers, cloud credentials, and
network. They pin contracts that normal Lambda unit tests cannot see: Terraform
must keep injecting the runtime-required environment variables, event sources,
and policy scopes that the Python handlers depend on.
"""

from __future__ import annotations

import ast
import re
from pathlib import Path
from typing import Iterable

import pytest

pytestmark = pytest.mark.contract

REPO_ROOT = Path(__file__).resolve().parents[2]


def read_repo_file(relative_path: str) -> str:
    return (REPO_ROOT / relative_path).read_text(encoding='utf-8')


def hcl_block(text: str, kind: str, *labels: str) -> str:
    label_text = ' '.join(f'"{label}"' for label in labels)
    needle = f'{kind} {label_text}'
    start = text.index(needle)
    brace_start = text.index('{', start)
    depth = 0
    for index in range(brace_start, len(text)):
        char = text[index]
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return text[brace_start:index + 1]
    raise ValueError(f'unclosed HCL block: {needle}')


def assignment_map_block(block: str, assignment: str) -> str:
    start = block.index(f'{assignment} = {{')
    brace_start = block.index('{', start)
    depth = 0
    for index in range(brace_start, len(block)):
        char = block[index]
        if char == '{':
            depth += 1
        elif char == '}':
            depth -= 1
            if depth == 0:
                return block[brace_start:index + 1]
    raise ValueError(f'unclosed map assignment: {assignment}')


def environment_keys(module_block: str) -> set[str]:
    env_block = assignment_map_block(module_block, 'environment_variables')
    return set(re.findall(r'^\s*([A-Z][A-Z0-9_]*)\s*=', env_block, re.MULTILINE))


class EnvReadVisitor(ast.NodeVisitor):
    def __init__(self) -> None:
        self.required: set[str] = set()
        self.optional: set[str] = set()

    def visit_Subscript(self, node: ast.Subscript) -> None:
        if isinstance(node.value, ast.Attribute):
            if self._is_os_environ(node.value):
                env_name = self._constant_string(node.slice)
                if env_name:
                    self.required.add(env_name)
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> None:
        if isinstance(node.func, ast.Attribute):
            if self._is_os_getenv(node.func) or self._is_os_environ_get(node.func):
                env_name = self._first_arg_string(node)
                if env_name:
                    self.optional.add(env_name)
        elif isinstance(node.func, ast.Name):
            if node.func.id in {
                'get_required_env',
                'parse_env_list',
                'parse_env_int',
            }:
                env_name = self._first_arg_string(node)
                if env_name:
                    self.required.add(env_name)
        self.generic_visit(node)

    @staticmethod
    def _constant_string(node: ast.AST) -> str:
        if isinstance(node, ast.Constant) and isinstance(node.value, str):
            return node.value
        return ''

    @staticmethod
    def _first_arg_string(node: ast.Call) -> str:
        if node.args:
            return EnvReadVisitor._constant_string(node.args[0])
        for keyword in node.keywords:
            if keyword.arg == 'name':
                return EnvReadVisitor._constant_string(keyword.value)
        return ''

    @staticmethod
    def _is_os_environ(node: ast.Attribute) -> bool:
        if node.attr != 'environ':
            return False
        if not isinstance(node.value, ast.Name):
            return False
        return node.value.id == 'os'

    @staticmethod
    def _is_os_getenv(node: ast.Attribute) -> bool:
        if node.attr != 'getenv':
            return False
        if not isinstance(node.value, ast.Name):
            return False
        return node.value.id == 'os'

    @staticmethod
    def _is_os_environ_get(node: ast.Attribute) -> bool:
        if node.attr != 'get':
            return False
        if not isinstance(node.value, ast.Attribute):
            return False
        return EnvReadVisitor._is_os_environ(node.value)


def python_env_reads(relative_path: str) -> tuple[set[str], set[str]]:
    tree = ast.parse(read_repo_file(relative_path), filename=relative_path)
    visitor = EnvReadVisitor()
    visitor.visit(tree)
    return visitor.required, visitor.optional


def assert_contains_all(text: str, expected: Iterable[str]) -> None:
    missing = [value for value in expected if value not in text]
    assert not missing, f'missing expected Terraform contract text: {missing}'


@pytest.mark.parametrize(
    'filename',
    [
        'billing_per_resource_process.tf',
        'billing_per_resource.tf',
        'billing_per_service.tf',
    ],
)
def test_splunk_aws_billing_packages_ignore_artifact_timestamps(
    filename: str,
) -> None:
    module_tf = read_repo_file(
        f'modules/integrations/splunk_aws_billing/{filename}'
    )

    assert 'trigger_on_package_timestamp = false' in module_tf


def test_job_log_pipeline_wires_runtime_env_and_event_contract() -> None:
    dispatcher_tf = read_repo_file(
        'modules/platform/forge_runners/github_actions_job_logs/'
        'job_log_dispatcher.tf'
    )
    archiver_tf = read_repo_file(
        'modules/platform/forge_runners/github_actions_job_logs/'
        'job_log_archiver.tf'
    )
    dispatcher_module = hcl_block(
        dispatcher_tf, 'module', 'job_log_dispatcher')
    archiver_module = hcl_block(archiver_tf, 'module', 'job_log_archiver')

    dispatcher_required, _dispatcher_optional = python_env_reads(
        'modules/platform/forge_runners/github_actions_job_logs/lambda/'
        'job_log_dispatcher/job_log_dispatcher.py'
    )
    archiver_required, _archiver_optional = python_env_reads(
        'modules/platform/forge_runners/github_actions_job_logs/lambda/'
        'job_log_archiver/job_log_archiver.py'
    )
    archiver_required.update({
        'BUCKET_NAME',
        'GITHUB_API',
        'KMS_KEY_ARN',
        'SECRET_NAME_APP_ID',
        'SECRET_NAME_INSTALLATION_ID',
        'SECRET_NAME_PRIVATE_KEY',
    })

    assert dispatcher_required <= environment_keys(dispatcher_module)
    assert archiver_required <= environment_keys(archiver_module)
    assert 'LOG_LEVEL' in environment_keys(dispatcher_module)
    assert 'LOG_LEVEL' in environment_keys(archiver_module)

    assert 'handler       = "job_log_dispatcher.lambda_handler"' in dispatcher_module
    assert 'handler       = "job_log_archiver.lambda_handler"' in archiver_module
    assert 'runtime       = "python3.12"' in dispatcher_module
    assert 'runtime       = "python3.12"' in archiver_module

    assert_contains_all(
        dispatcher_tf,
        [
            '"detail-type": ["workflow_job"]',
            '"action": ["completed"]',
            'QUEUE_URL = aws_sqs_queue.jobs.url',
            'actions = ["sqs:SendMessage", "sqs:SendMessageBatch"]',
            'resources = [\n      aws_sqs_queue.jobs.arn',
        ],
    )
    assert_contains_all(
        archiver_tf,
        [
            'event_source_arn = aws_sqs_queue.jobs.arn',
            'batch_size       = 1',
            'actions = [\n      "sqs:ReceiveMessage",',
            'resources = [aws_sqs_queue.jobs.arn]',
            'resources = [aws_kms_key.gh_logs.arn]',
            'var.github_app.id_ssm.arn',
            'var.github_app.key_base64_ssm.arn',
            'var.github_app.installation_id_ssm.arn',
        ],
    )


def test_job_log_bucket_security_controls_are_preserved() -> None:
    s3_tf = read_repo_file(
        'modules/platform/forge_runners/github_actions_job_logs/s3.tf'
    )
    public_access = hcl_block(
        s3_tf,
        'resource',
        'aws_s3_bucket_public_access_block',
        'gh_logs',
    )
    kms_key = hcl_block(s3_tf, 'resource', 'aws_kms_key', 'gh_logs')
    encryption = hcl_block(
        s3_tf,
        'resource',
        'aws_s3_bucket_server_side_encryption_configuration',
        'gh_logs',
    )
    versioning = hcl_block(
        s3_tf,
        'resource',
        'aws_s3_bucket_versioning',
        'gh_logs',
    )
    lifecycle = hcl_block(
        s3_tf,
        'resource',
        'aws_s3_bucket_lifecycle_configuration',
        'gh_logs',
    )
    read_policy = hcl_block(
        s3_tf, 'resource', 'aws_s3_bucket_policy', 'gh_logs_read')

    assert_contains_all(
        public_access,
        [
            'block_public_acls       = true',
            'block_public_policy     = true',
            'ignore_public_acls      = true',
            'restrict_public_buckets = true',
        ],
    )
    assert 'enable_key_rotation     = true' in kms_key
    assert 'sse_algorithm     = "aws:kms"' in encryption
    assert 'kms_master_key_id = aws_kms_key.gh_logs.arn' in encryption
    assert 'status = "Enabled"' in versioning
    assert 'abort_incomplete_multipart_upload { days_after_initiation = 7 }' in lifecycle
    assert 'Principal = {\n          AWS = aws_iam_role.internal_s3_reader.arn' in read_policy
    assert 'Principal = "*"' not in read_policy


def test_splunk_stuck_dispatcher_worker_contract_is_offline_and_scoped() -> None:
    lambda_tf = read_repo_file(
        'modules/integrations/splunk_stuck_workflow_job_dispatcher/lambda.tf'
    )
    dynamodb_tf = read_repo_file(
        'modules/integrations/splunk_stuck_workflow_job_dispatcher/dynamodb.tf'
    )
    tenant_configs_tf = read_repo_file(
        'modules/integrations/splunk_stuck_workflow_job_dispatcher/'
        'tenant_configs.tf'
    )
    dispatcher_module = hcl_block(lambda_tf, 'module', 'dispatcher')
    worker_module = hcl_block(lambda_tf, 'module', 'worker')

    dispatcher_required, _dispatcher_optional = python_env_reads(
        'modules/integrations/splunk_stuck_workflow_job_dispatcher/'
        'lambda/handler.py'
    )
    worker_required, _worker_optional = python_env_reads(
        'modules/integrations/splunk_stuck_workflow_job_dispatcher/'
        'lambda/worker.py'
    )

    assert dispatcher_required <= environment_keys(dispatcher_module)
    assert worker_required <= environment_keys(worker_module)
    assert {'LOG_LEVEL', 'DEDUPE_TTL_SECONDS'} <= environment_keys(
        dispatcher_module)
    assert 'LOG_LEVEL' in environment_keys(worker_module)

    assert_contains_all(
        dynamodb_tf,
        [
            'stream_enabled   = true',
            'stream_view_type = "NEW_IMAGE"',
            'billing_mode     = "PAY_PER_REQUEST"',
            'point_in_time_recovery {\n    enabled = true',
            'attribute_name = "expires_at"',
        ],
    )
    assert_contains_all(
        lambda_tf,
        [
            'event_source_arn  = aws_dynamodb_table.dedupe.stream_arn',
            'starting_position = "LATEST"',
            'batch_size        = 10',
            'TENANT_CONFIG_PARAMETER_COUNT  = tostring(length(local.redelivery_tenant_config_chunks))',
            'TENANT_CONFIG_PARAMETER_PREFIX = local.redelivery_tenant_config_parameter_prefix',
            'aws_ssm_parameter.tenant_configs',
            'sid    = "ReadTenantGitHubAppParameters"',
            '"arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter/forge/*/github_app_*"',
            'sid    = "ReadDispatcherTenantConfigParameters"',
            'for parameter in aws_ssm_parameter.tenant_configs : parameter.arn',
            'variable = "kms:ViaService"',
            'values   = ["ssm.*.amazonaws.com"]',
        ],
    )
    assert 'type           = "String"' in tenant_configs_tf
    assert 'insecure_value = each.value' in tenant_configs_tf
    assert 'depends_on = [aws_cloudwatch_log_group.worker]' in worker_module
    assert 'aws_ssm_parameter.tenant_configs' not in worker_module


def test_redrive_deadletter_policy_scope_is_configured_from_sqs_map() -> None:
    main_tf = read_repo_file(
        'modules/platform/forge_runners/redrive_deadletter/main.tf'
    )
    lambda_module = hcl_block(main_tf, 'module', 'redrive_deadletter_lambda')
    policy_doc = hcl_block(
        main_tf,
        'data',
        'aws_iam_policy_document',
        'redrive_deadletter_lambda',
    )

    required_env, _optional_env = python_env_reads(
        'modules/platform/forge_runners/redrive_deadletter/lambda/'
        'redrive_deadletter.py'
    )

    assert required_env <= environment_keys(lambda_module)
    assert 'SQS_MAP   = jsonencode(var.sqs_map)' in lambda_module
    assert 'handler       = "redrive_deadletter.lambda_handler"' in lambda_module
    assert 'runtime       = "python3.12"' in lambda_module
    assert 'schedule_expression = "cron(*/10 * * * ? *)"' in main_tf

    assert_contains_all(
        policy_doc,
        [
            'sid    = "SQSReceiveFromDLQ"',
            '"sqs:StartMessageMoveTask"',
            '"sqs:ReceiveMessage"',
            '"sqs:GetQueueAttributes"',
            '"sqs:DeleteMessage"',
            'cfg.dlq',
            'sid    = "SQSSendToMainQueue"',
            '"sqs:SendMessage"',
            'cfg.main',
        ],
    )
    assert 'resources = ["*"]' not in policy_doc


def test_forge_subscription_ecr_cross_product_uses_region_provider_alias() -> None:
    ecr_tf = read_repo_file('modules/helpers/forge_subscription/ecr.tf')
    providers_tf = read_repo_file(
        'modules/helpers/forge_subscription/providers.tf')
    variables_tf = read_repo_file(
        'modules/helpers/forge_subscription/variables.tf')
    ecr_policy_doc = hcl_block(
        ecr_tf,
        'data',
        'aws_iam_policy_document',
        'ecr_repository_policy',
    )
    ecr_policy_resource = hcl_block(
        ecr_tf,
        'resource',
        'aws_ecr_repository_policy',
        'repository_policy',
    )

    assert_contains_all(
        ecr_tf,
        [
            'ecr_repo_region_pairs = flatten([',
            'for region in var.forge.ecr_repositories.regions : [',
            'for name in var.forge.ecr_repositories.names : {',
            'region = region',
            'name   = name',
        ],
    )
    assert_contains_all(
        ecr_policy_doc,
        [
            'identifiers = var.forge.ecr_repositories.ecr_access_account_ids',
            '"ecr:GetDownloadUrlForLayer"',
            '"ecr:BatchCheckLayerAvailability"',
            '"ecr:BatchGetImage"',
            '"ecr:DescribeImages"',
            '"ecr:GetAuthorizationToken"',
            '"ecr:ListImages"',
        ],
    )
    assert_contains_all(
        ecr_policy_resource,
        [
            'for pair in local.ecr_repo_region_pairs : "${pair.region}/${pair.name}" => pair',
            'provider = aws.by_region[each.value.region]',
            'repository = each.value.name',
            'policy     = data.aws_iam_policy_document.ecr_repository_policy.json',
        ],
    )
    assert 'module "ecr_repository_policy_by_region"' not in ecr_tf
    assert_contains_all(
        providers_tf,
        [
            'alias = "by_region"',
            'for_each = toset(var.forge.ecr_repositories.regions)',
            'region   = each.key',
        ],
    )
    assert_contains_all(
        variables_tf,
        [
            'runner_roles = list(string)',
            'names                  = list(string)',
            'ecr_access_account_ids = list(string)',
            'regions                = list(string)',
        ],
    )


def test_forge_trust_validator_keeps_delayed_validation_contract() -> None:
    main_tf = read_repo_file(
        'modules/platform/forge_runners/forge_trust_validator/main.tf'
    )
    preparer_module = hcl_block(
        main_tf, 'module', 'forge_trust_preparer_lambda')
    validator_module = hcl_block(
        main_tf, 'module', 'forge_trust_validator_lambda')

    preparer_required, _preparer_optional = python_env_reads(
        'modules/platform/forge_runners/forge_trust_validator/lambda/'
        'trust_preparer.py'
    )
    assert preparer_required <= environment_keys(preparer_module)
    assert environment_keys(validator_module) == {'LOG_LEVEL'}

    assert_contains_all(
        preparer_module,
        [
            'handler                        = "trust_preparer.prepare_handler"',
            'reserved_concurrent_executions = 1',
            'VALIDATION_DELAY_SECONDS  = tostring(var.iam_propagation_delay_seconds)',
            'VALIDATION_QUEUE_URL      = aws_sqs_queue.forge_trust_validator.url',
        ],
    )
    assert_contains_all(
        validator_module,
        [
            'handler                        = "trust_validator.validate_handler"',
            'reserved_concurrent_executions = 1',
        ],
    )
    assert_contains_all(
        main_tf,
        [
            'message_retention_seconds  = 86400',
            'visibility_timeout_seconds = 960',
            'schedule_expression = "cron(*/10 * * * ? *)"',
            'event_source_arn = aws_sqs_queue.forge_trust_validator.arn',
            'batch_size       = 1',
            'actions = [\n      "iam:GetRole",',
            'resources = [for key, arn in var.forge_iam_roles : arn]',
            'actions = [\n      "sts:AssumeRole",',
            'actions = [\n      "sqs:ChangeMessageVisibility",',
            'resources = [aws_sqs_queue.forge_trust_validator.arn]',
        ],
    )


def test_webhook_relay_source_wires_signature_boundary() -> None:
    lambda_tf = read_repo_file(
        'modules/platform/forge_runners/github_webhook_relay/source/lambda.tf'
    )
    module = hcl_block(lambda_tf, 'module', 'validate_signature_lambda')
    required, _optional = python_env_reads(
        'modules/platform/forge_runners/github_webhook_relay/source/lambda/'
        'validate_signature.py'
    )

    assert required <= environment_keys(module)
    assert {'EVENT_SOURCE', 'LOG_LEVEL'} <= environment_keys(module)
    assert_contains_all(
        lambda_tf,
        [
            'handler       = "validate_signature.lambda_handler"',
            'runtime       = "python3.12"',
            'EVENT_BUS      = var.source_event_bus_name',
            'WEBHOOK_SECRET = var.webhook_secret',
            'actions = [\n      "events:PutEvents"',
            'resources = [\n      aws_cloudwatch_event_bus.source.arn',
        ],
    )


def test_webhook_relay_destination_keeps_bus_and_reader_contract() -> None:
    destination_tf = read_repo_file(
        'modules/integrations/github_webhook_relay_destination/'
        'webhook_relay_destination.tf'
    )
    source_tf = read_repo_file(
        'modules/integrations/github_webhook_relay_destination/'
        'webhook_relay_source.tf'
    )
    bus_policy = hcl_block(
        destination_tf,
        'resource',
        'aws_cloudwatch_event_bus_policy',
        'allow_source',
    )
    reader_trust = hcl_block(
        source_tf,
        'data',
        'aws_iam_policy_document',
        'trust',
    )

    assert_contains_all(
        bus_policy,
        [
            'Principal = { AWS = var.webhook_relay_destination_config.source_account_id }',
            'Action    = "events:PutEvents"',
            'Resource  = aws_cloudwatch_event_bus.destination.arn',
        ],
    )
    assert_contains_all(
        destination_tf,
        [
            'for idx, t in var.webhook_relay_destination_config.targets : idx => t',
            'event_pattern  = each.value.event_pattern',
            'arn            = local.targets_indexed[each.key].lambda_function_arn',
            'principal     = "events.amazonaws.com"',
            'source_arn    = each.value.arn',
        ],
    )
    assert_contains_all(
        reader_trust,
        [
            'identifiers = var.reader_config.role_trust_principals',
            'actions = ["sts:AssumeRole"]',
        ],
    )
    assert_contains_all(
        source_tf,
        [
            'count = var.reader_config.enable_secret_fetch ? 1 : 0',
            'actions   = ["sts:AssumeRole"]',
            'resources = [var.reader_config.source_secret_role_arn]',
            'aws_iam_role.reader.arn',
            'var.reader_config.source_secret_arn',
        ],
    )


def test_ec2_runner_tag_policy_keeps_environment_resource_condition() -> None:
    main_tf = read_repo_file(
        'modules/platform/ec2_deployment/ec2_update_runner_tags/main.tf'
    )
    policy = hcl_block(
        main_tf,
        'data',
        'aws_iam_policy_document',
        'ec2_update_runner_tags_lambda',
    )

    assert_contains_all(
        policy,
        [
            'actions   = ["ec2:DescribeInstances"]',
            '"ec2:CreateTags"',
            '"ec2:DeleteTags"',
            'resources = ["*"]',
            'condition {\n      test     = "StringLike"',
            'variable = "ec2:ResourceTag/ghr:environment"',
            'values   = ["${var.prefix}-*"]',
        ],
    )
