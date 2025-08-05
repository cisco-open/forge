resource "null_resource" "update_github_app_webhook" {
  triggers = {
    ghes_org       = var.ghes_org
    ghes_url       = var.ghes_url
    webhook_url    = module.ec2_runners.webhook_endpoint
    secret         = random_id.random.hex
    secret_version = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].id
  }

  provisioner "local-exec" {
    environment = {
      CLIENT_ID = data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_client_id"].secret_string
      PRIVATE_KEY = base64decode(
        data.aws_secretsmanager_secret_version.data_cicd_secrets["${local.cicd_secrets_prefix}github_actions_runners_app_key"].secret_string
      )
      WEBHOOK_URL = self.triggers.webhook_url
      SECRET      = self.triggers.secret
      GITHUB_API  = local.github_api
    }

    command = "${path.module}/scripts/generate_and_patch_github_app.sh"
  }

  depends_on = [
    data.aws_secretsmanager_secret_version.data_cicd_secrets,
  ]
}
