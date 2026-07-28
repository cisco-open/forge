resource "aws_servicecatalogappregistry_application" "this" {
  name = "integrations_splunk_stuck_workflow_job_dispatcher_${var.aws_region}"
  tags = merge(var.default_tags, var.tags)
}
