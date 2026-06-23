data "aws_secretsmanager_secret" "splunk_cloud_api_token" {
  name = "/cicd/common/splunk_cloud_api_token"
}

data "aws_secretsmanager_secret_version" "splunk_cloud_api_token" {
  secret_id = data.aws_secretsmanager_secret.splunk_cloud_api_token.id
}
