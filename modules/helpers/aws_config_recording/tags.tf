# Common tags we propagate project-wide.
locals {
  all_security_tags = merge(
    var.default_tags,
    var.tags,
    aws_servicecatalogappregistry_application.this.application_tag,
  )
  create_delivery_resources = var.delivery_bucket_name == null
  delivery_bucket_name = coalesce(
    var.delivery_bucket_name,
    "${data.aws_caller_identity.current.account_id}-forge-aws-config-${var.aws_region}",
  )
  config_events_queue_name = "${data.aws_caller_identity.current.account_id}-forge-aws-config-events-${var.aws_region}"
  config_events_dlq_name   = "${data.aws_caller_identity.current.account_id}-forge-aws-config-events-dlq-${var.aws_region}"
  iam_role_name            = coalesce(var.iam_role_name, "forge-aws-config-recorder-${var.aws_region}")
}
