data "external" "ensure_template_file" {
  program = ["bash", "-c", <<-EOT
    FILE="/tmp/${random_uuid.splunk_input_uuid.result}_template.json"
    [ -f "$FILE" ] || echo '{}' > "$FILE"
    echo "{ \"md5\": \"$(md5sum $FILE | awk '{print $1}')\" }"
  EOT
  ]
}

resource "aws_s3_object" "cloudformation_template" {
  bucket = var.cloudformation_s3_config.bucket
  key    = "${var.cloudformation_s3_config.key}${random_uuid.splunk_input_uuid.result}/template.json"
  source = "/tmp/${random_uuid.splunk_input_uuid.result}_template.json"
  etag   = data.external.ensure_template_file.result["md5"]

  depends_on = [
    data.external.ensure_template_file,
    null_resource.create_integration,
    random_uuid.splunk_input_uuid,
  ]
}
