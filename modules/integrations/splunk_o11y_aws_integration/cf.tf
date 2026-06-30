resource "aws_cloudformation_stack" "splunk_integration" {
  #checkov:skip=CKV_AWS_124:Splunk-managed CloudFormation integration stack does not require SNS notifications in this module.
  name = "splunk-integration"

  parameters = {
    SplunkAccessToken = data.aws_secretsmanager_secret_version.secrets["splunk_o11y_ingest_token_aws_integration"].secret_string
    SplunkIngestUrl   = var.splunk_ingest_url
  }

  template_url = var.template_url

  capabilities = [
    "CAPABILITY_AUTO_EXPAND",
    "CAPABILITY_NAMED_IAM"
  ]

  tags     = local.all_security_tags
  tags_all = local.all_security_tags

}
