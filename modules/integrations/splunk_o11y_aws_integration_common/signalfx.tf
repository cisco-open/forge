resource "signalfx_aws_external_integration" "integration" {
  name = var.integration_name
}

resource "signalfx_aws_integration" "integration" {
  enabled = true

  integration_id            = signalfx_aws_external_integration.integration.id
  external_id               = signalfx_aws_external_integration.integration.external_id
  role_arn                  = aws_iam_role.splunk_integration.arn
  regions                   = var.integration_regions
  import_cloud_watch        = true
  enable_aws_usage          = true
  use_metric_streams_sync   = true
  enable_check_large_volume = true

  depends_on = [time_sleep.wait_30_seconds]
}

# Force a delay between secret creation and seeding. We only need a few
# seconds, but if we don't do this, we get into a bad state requiring manual
# intervention and/or manual forced-deletion of secrets.
resource "time_sleep" "wait_30_seconds" {
  depends_on = [
    aws_iam_role.splunk_integration,
  ]
  create_duration = "30s"
}
