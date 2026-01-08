resource "aws_s3_object" "cloudformation_template" {
  bucket = var.cloudformation_s3_config.bucket
  key    = "${var.cloudformation_s3_config.key}${random_uuid.splunk_input_uuid.result}/template.json"
  source = "/tmp/${random_uuid.splunk_input_uuid.result}_template.json"

  source_hash = filemd5("/tmp/${random_uuid.splunk_input_uuid.result}_template.json")

  depends_on = [
    data.external.splunk_dm_version,
    random_uuid.splunk_input_uuid,
  ]
}
