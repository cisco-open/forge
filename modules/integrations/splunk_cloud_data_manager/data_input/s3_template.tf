resource "aws_s3_object" "cloudformation_template" {
  bucket = var.cloudformation_s3_config.bucket
  key    = "${var.cloudformation_s3_config.key}${random_uuid.splunk_input_uuid.result}/template.json"
  source = "/tmp/${random_uuid.splunk_input_uuid.result}_template.json"

  depends_on = [
    null_resource.create_integration,
    random_uuid.splunk_input_uuid,
  ]
}
