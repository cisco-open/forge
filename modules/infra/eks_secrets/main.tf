locals {
  cicd_secrets_prefix = "/cicd/common"

  secrets = [

    {
      name          = "${local.cicd_secrets_prefix}/dockerhub_user"
      description   = "DockerHub o11y User"
      recovery_days = 7
    },
    {
      name          = "${local.cicd_secrets_prefix}/dockerhub_token"
      description   = "DockerHub o11y Token"
      recovery_days = 7
    },
    {
      name          = "${local.cicd_secrets_prefix}/dockerhub_email"
      description   = "DockerHub o11y Email"
      recovery_days = 7
    },
  ]

  all_regions = toset(concat([var.aws_region], var.replica_regions))
}

# Psuedo-random seeds we use for initializing the secrets. If we don't do this,
# then the secret "exists", but has no value or initial version, and "tf apply"
# steps fail, requiring one to manually set the password outside of Terraform.
data "aws_secretsmanager_random_password" "secret_seeds" {
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  password_length = 16
}

resource "aws_kms_key" "regional" {
  for_each = local.all_regions
  provider = aws.by_region[each.value]

  description         = "Customer managed CMK for EKS Secrets in ${each.key}"
  enable_key_rotation = true

  tags     = local.all_security_tags
  tags_all = local.all_security_tags
}

resource "aws_kms_alias" "regional_alias" {
  for_each = aws_kms_key.regional
  provider = aws.by_region[each.key]

  name          = "alias/eks-cmk-${each.key}"
  target_key_id = each.value.id
}

# Actual object containing the secret.
resource "aws_secretsmanager_secret" "cicd_secrets" {
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  name                    = each.value.name
  description             = each.value.description
  kms_key_id              = aws_kms_key.regional[var.aws_region].arn
  recovery_window_in_days = each.value.recovery_days
  tags                    = local.all_security_tags
  tags_all                = local.all_security_tags

  dynamic "replica" {
    for_each = var.replica_regions
    content {
      region     = replica.value
      kms_key_id = aws_kms_key.regional[replica.value].arn
    }
  }

}

# Force a delay between secret creation and seeding. We only need a few
# seconds, but if we don't do this, we get into a bad state requiring manual
# intervention and/or manual forced-deletion of secrets.
resource "time_sleep" "wait_60_seconds" {
  depends_on = [
    aws_secretsmanager_secret.cicd_secrets,
  ]
  create_duration = "60s"
}

# Only used for seeding purposes. Will not clobber/overwrite secrets afterward
# (i.e. if/when we set them manually via the AWS CLI or management console).
resource "aws_secretsmanager_secret_version" "cicd_secrets" {
  depends_on = [time_sleep.wait_60_seconds]
  for_each = {
    for key, val in local.secrets : val.name => val
  }

  secret_id     = aws_secretsmanager_secret.cicd_secrets[each.key].id
  secret_string = data.aws_secretsmanager_random_password.secret_seeds[each.key].random_password

  # Prevents this seed from being applied more than once (at initial "tf apply"
  # time).
  lifecycle {
    ignore_changes = [secret_string, ]
  }
}
