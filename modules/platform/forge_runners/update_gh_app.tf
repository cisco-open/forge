resource "null_resource" "update_github_app_webhook" {
  triggers = {
    ghes_org       = var.deployment_config.github.ghes_org
    ghes_url       = var.deployment_config.github.ghes_url
    webhook_url    = try(module.ec2_runners[0].webhook_endpoint, "https://cisco-open.github.io/forge")
    secret_version = aws_ssm_parameter.github_app_webhook_secret.version
    key_version    = aws_ssm_parameter.github_app_key.version
  }

  provisioner "local-exec" {
    environment = {
      CLIENT_ID       = var.deployment_config.github_app.client_id
      AWS_REGION      = var.aws_region
      AWS_PROFILE     = var.aws_profile
      PRIVATE_KEY_ARN = aws_ssm_parameter.github_app_key.arn
      WEBHOOK_URL     = self.triggers.webhook_url
      SECRET_ARN      = aws_ssm_parameter.github_app_webhook_secret.arn
      GITHUB_API      = local.github_api
      PREFIX          = "${var.deployment_config.env}-${var.deployment_config.deployment_prefix}"
    }

    command = "${path.module}/scripts/generate_and_patch_github_app.sh"
  }
}
