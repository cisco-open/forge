resource "terraform_data" "cloudwatch_metric_stream_tags" {
  input = {
    aws_profile        = var.aws_profile
    region             = var.aws_region
    stack_id           = aws_cloudformation_stack.splunk_integration.id
    stream_name_prefix = "splunk-metric-stream-"

    # Stored in Terraform state so the destroy provisioner knows which
    # keys were managed by the previous configuration.
    tags = local.all_security_tags
  }

  # local-exec provisioners do not run for an in-place terraform_data update,
  # so stack, template, script, and tag changes must replace this resource.
  triggers_replace = [
    aws_cloudformation_stack.splunk_integration.id,
    var.template_url,
    filesha256("${path.module}/scripts/manage_cloudwatch_metric_stream_tags.py"),
    sha256(jsonencode(local.all_security_tags)),
  ]

  # Apply all desired tags. Splunk creates its managed Metric Stream
  # asynchronously after the CloudFormation prerequisites are available.
  provisioner "local-exec" {
    working_dir = path.module

    environment = {
      AWS_PAGER          = ""
      AWS_PROFILE        = self.input.aws_profile
      AWS_REGION         = self.input.region
      STREAM_NAME_PREFIX = self.input.stream_name_prefix
      TAG_COUNT          = tostring(length(self.input.tags))

      TAGS_JSON = jsonencode([
        for key in sort(keys(self.input.tags)) : {
          Key   = key
          Value = self.input.tags[key]
        }
      ])
    }

    command = "python3 ./scripts/manage_cloudwatch_metric_stream_tags.py apply"
  }

  # Remove all keys managed by the previous instance of this helper.
  #
  # This runs when:
  # - a tag is deleted from local.all_security_tags;
  # - a tag value changes;
  # - the CloudFormation stack or template changes;
  # - the helper script changes;
  # - terraform destroy is executed.
  provisioner "local-exec" {
    when        = destroy
    working_dir = path.module

    environment = {
      AWS_PAGER          = ""
      AWS_PROFILE        = self.input.aws_profile
      AWS_REGION         = self.input.region
      STREAM_NAME_PREFIX = self.input.stream_name_prefix
      TAG_COUNT          = tostring(length(self.input.tags))
      TAG_KEYS_JSON = jsonencode(
        sort(keys(self.input.tags))
      )
    }

    command = "python3 ./scripts/manage_cloudwatch_metric_stream_tags.py remove"
  }

  depends_on = [
    aws_cloudformation_stack.splunk_integration,
  ]
}
