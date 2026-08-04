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
    command = "python3.12 \"${path.module}/scripts/splunk_integration.py\" create"

    environment = {
      SPLUNK_CLOUD            = var.splunk_cloud
      SPLUNK_INPUT_UUID       = random_uuid.splunk_input_uuid.result
      SPLUNK_CLOUD_USERNAME   = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_username"].secret_string
      SPLUNK_CLOUD_PASSWORD   = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_password"].secret_string
      SPLUNK_CLOUD_INPUT_JSON = var.splunk_cloud_input_json
    }
  }
  depends_on = [
    null_resource.delete_integration,
  ]
}

data "external" "splunk_dm_version" {
  program = [
    "python3.12",
    "${path.module}/scripts/splunk_integration.py",
    "get",
  ]

  query = {
    SPLUNK_CLOUD            = var.splunk_cloud
    SPLUNK_INPUT_UUID       = random_uuid.splunk_input_uuid.result
    SPLUNK_CLOUD_USERNAME   = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_username"].secret_string
    SPLUNK_CLOUD_PASSWORD   = data.aws_secretsmanager_secret_version.secrets["splunk_cloud_password"].secret_string
    SPLUNK_CLOUD_INPUT_JSON = var.splunk_cloud_input_json
  }

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

    command = "python3.12 ./scripts/splunk_integration.py delete"

    environment = {
      SPLUNK_CLOUD          = self.triggers.splunk_cloud
      SPLUNK_INPUT_UUID     = self.triggers.splunk_input_uuid
      SPLUNK_CLOUD_USERNAME = self.triggers.splunk_cloud_username
      SPLUNK_CLOUD_PASSWORD = self.triggers.splunk_cloud_password
    }
  }
}
