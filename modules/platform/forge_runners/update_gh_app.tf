resource "null_resource" "update_github_app_webhook" {
  triggers = {
    ghes_org        = var.deployment_config.github.ghes_org
    ghes_url        = var.deployment_config.github.ghes_url
    webhook_url     = try(module.ec2_runners[0].webhook_endpoint, "https://cisco-open.github.io/forge")
    secret          = aws_ssm_parameter.github_app_webhook_secret.value
    secret_version  = aws_ssm_parameter.github_app_webhook_secret.version
    id              = var.deployment_config.github_app.id
    client_id       = var.deployment_config.github_app.client_id
    installation_id = var.deployment_config.github_app.installation_id
    name            = var.deployment_config.github_app.name
  }

  provisioner "local-exec" {
    environment = {
      CLIENT_ID = var.deployment_config.github_app.client_id
      PRIVATE_KEY = base64decode(
        data.aws_ssm_parameter.github_app_key.value
      )
      WEBHOOK_URL = self.triggers.webhook_url
      SECRET      = self.triggers.secret
      GITHUB_API  = local.github_api
      PREFIX      = "${var.deployment_config.env}-${var.deployment_config.deployment_prefix}"
    }

    command = "${path.module}/scripts/generate_and_patch_github_app.sh"
  }
}
