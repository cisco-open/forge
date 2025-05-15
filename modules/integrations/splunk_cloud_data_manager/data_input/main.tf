resource "random_uuid" "splunk_input_uuid" {}

resource "null_resource" "create_integration" {
  triggers = {
    splunk_cloud_input_json = var.splunk_cloud_input_json
    splunk_cloud            = var.splunk_cloud
    splunk_input_uuid       = random_uuid.splunk_input_uuid.result
    splunk_cloud_username   = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_username"].secret_string
    splunk_cloud_password   = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_password"].secret_string
  }
  provisioner "local-exec" {
    command = <<-EOC
      export SPLUNK_CLOUD_INPUT_JSON='${var.splunk_cloud_input_json}'

      ${path.module}/scripts/create_splunk_integration.sh '${var.splunk_cloud}' '${random_uuid.splunk_input_uuid.result}' '${data.aws_secretsmanager_secret_version.secrets["splunk_cloud_username"].secret_string}' '${data.aws_secretsmanager_secret_version.secrets["splunk_cloud_password"].secret_string}'
    EOC
  }
  depends_on = [
    null_resource.delete_integration,
  ]
}

data "external" "splunk_dm_version" {
  program = [
    "bash", "-c",
    <<-EOF
      ${path.module}/scripts/get_splunk_integration.sh '${var.splunk_cloud}' '${random_uuid.splunk_input_uuid.result}' '${data.aws_secretsmanager_secret_version.secrets["splunk_cloud_username"].secret_string}' '${data.aws_secretsmanager_secret_version.secrets["splunk_cloud_password"].secret_string}'
    EOF
  ]
  depends_on = [
    null_resource.create_integration
  ]
}

resource "null_resource" "delete_integration" {
  triggers = {
    splunk_cloud          = var.splunk_cloud
    splunk_input_uuid     = random_uuid.splunk_input_uuid.result
    splunk_cloud_username = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_username"].secret_string
    splunk_cloud_password = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_password"].secret_string
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = path.module

    command = <<-EOC
      ./scripts/delete_splunk_integration.sh '${self.triggers.splunk_cloud}' '${self.triggers.splunk_input_uuid}' '${self.triggers.splunk_cloud_username}' '${self.triggers.splunk_cloud_password}'
    EOC
  }
}
