resource "local_file" "github_app_pem" {
  filename = "${path.module}/github_app_key.pem"
  content = base64decode(
    data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].secret_string
  )
}

data "external" "github_app_jwt" {
  program = [
    "${path.module}/scripts/generate_github_jwt.sh",
    data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_client_id"].secret_string,
    local_file.github_app_pem.filename
  ]
}

resource "null_resource" "update_github_app_webhook" {
  triggers = {
    webhook_url    = module.ec2_runners.webhook_endpoint
    secret         = random_id.random.hex
    content_sha256 = local_file.github_app_pem.content_sha256
  }

  provisioner "local-exec" {
    environment = {
      WEBHOOK_URL = self.triggers.webhook_url
      SECRET      = self.triggers.secret
      JWT         = data.external.github_app_jwt.result.jwt
    }

    command = <<EOT
curl -s -X PATCH https://api.github.com/app/hook/config \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  -d "{
    \"url\": \"$WEBHOOK_URL\",
    \"content_type\": \"json\",
    \"insecure_ssl\": \"0\",
    \"secret\": \"$SECRET\"
  }"
EOT
  }

  depends_on = [
    data.aws_secretsmanager_secret_version.data_cicd_secrets,
    local_file.github_app_pem,
    data.external.github_app_jwt
  ]
}
