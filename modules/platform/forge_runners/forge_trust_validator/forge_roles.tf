data "aws_iam_role" "forge" {
  for_each = toset(var.forge_iam_roles)

  name = replace(each.value, "/^.*//", "")
}

locals {
  # Statement we want to add to EVERY forge IAM role
  lambda_trust_statement = {
    Sid    = "AllowLambdaValidationAssume"
    Effect = "Allow"
    Principal = {
      AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.prefix}-forge-trust-validator"
    }
    Action = "sts:AssumeRole"
  }

  # original_trust[arn] = decoded assume_role_policy JSON for each role
  original_trust = {
    for arn, role in data.aws_iam_role.forge :
    arn => jsondecode(role.assume_role_policy)
  }

  # original_statements[arn] = existing Statements list (or [])
  original_statements = {
    for arn, trust in local.original_trust :
    arn => try(trust.Statement, [])
  }

  # updated_statements[arn]: ensure exactly one statement with this Sid
  updated_statements = {
    for arn, stmts in local.original_statements :
    arn => concat(
      [
        for s in stmts :
        s if !(can(s.Sid) && s.Sid == local.lambda_trust_statement.Sid)
      ],
      [local.lambda_trust_statement]
    )
  }

  # concatenated_trust_object[arn] = full updated policy for each role
  concatenated_trust_object = {
    for arn, trust in local.original_trust :
    arn => {
      Version   = try(trust.Version, "2012-10-17")
      Statement = local.updated_statements[arn]
    }
  }

  # concatenated_trust_json[arn] = final JSON string for each role
  concatenated_trust_json = {
    for arn, obj in local.concatenated_trust_object :
    arn => jsonencode(obj)
  }
}

resource "null_resource" "update_forge_role_trust" {
  for_each = data.aws_iam_role.forge

  triggers = {
    role_name  = each.value.name
    future_sha = sha1(local.concatenated_trust_json[each.key])
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      set -euo pipefail

      ROLE_NAME="${each.value.name}"
      TMP_FILE="/tmp/${each.value.name}-trust.json"

      cat > "$${TMP_FILE}" << 'JSON'
${local.concatenated_trust_json[each.key]}
JSON

      aws iam update-assume-role-policy \
        --role-name "$${ROLE_NAME}" \
        --policy-document "file://$${TMP_FILE}" \
        --profile "${var.aws_profile}"
    EOT
  }
}
