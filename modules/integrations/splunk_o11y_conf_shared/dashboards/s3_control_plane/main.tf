locals {
  aws_account_ids = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_account_id"
  ]))
  aws_regions = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_region"
  ]))
  product_family_names = distinct(flatten([
    for var_def in var.dynamic_variables : var_def.values_suggested
    if var_def.property == "aws_tag_ProductFamilyName"
  ]))

  aws_account_filter = length(local.aws_account_ids) > 0 ? join(" or ", [
    for account_id in sort(local.aws_account_ids) : "filter('aws_account_id', '${account_id}')"
  ]) : "filter('aws_account_id', '__forge_aws_account_scope_not_configured__')"
  aws_region_filter = length(local.aws_regions) > 0 ? join(" or ", [
    for aws_region in sort(local.aws_regions) : "filter('aws_region', '${aws_region}')"
  ]) : "filter('aws_region', '__forge_aws_region_scope_not_configured__')"
  product_family_filter = length(local.product_family_names) > 0 ? join(" or ", [
    for product_family_name in sort(local.product_family_names) : "filter('aws_tag_ProductFamilyName', '${product_family_name}')"
  ]) : "filter('aws_tag_ProductFamilyName', '__forge_product_family_scope_not_configured__')"

  aws_platform_filter  = "(${local.aws_account_filter}) and (${local.aws_region_filter}) and (${local.product_family_filter})"
  control_plane_filter = "(${local.aws_platform_filter}) and (not filter('aws_tag_TenantName', '*'))"
  s3_dimension_filter  = "filter('namespace', 'AWS/S3') and filter('BucketName', '*')"
}

resource "signalfx_single_value_chart" "active_buckets" {
  name        = "# Control-plane buckets"
  description = "Number of untagged Forge S3 buckets reporting daily storage metrics."

  program_text = "A = data('NumberOfObjects', filter=(${local.control_plane_filter}) and (${local.s3_dimension_filter}) and filter('StorageType', 'AllStorageTypes') and filter('stat', 'mean'), rollup='latest').count(by=['BucketName']).count().publish(label='A')"

  color_by = "Dimension"

  viz_options {
    display_name = "Control-plane buckets"
    label        = "A"
  }
}

resource "signalfx_list_chart" "bucket_size" {
  name        = "Largest control-plane buckets"
  description = "Latest S3 bucket size, summed across storage classes, for Forge buckets without TenantName."

  program_text = "A = data('BucketSizeBytes', filter=(${local.control_plane_filter}) and (${local.s3_dimension_filter}) and filter('stat', 'mean'), rollup='latest').sum(by=['aws_region', 'BucketName']).top(count=20).publish(label='A')"
  sort_by      = "-value"

  disable_sampling        = true
  hide_missing_values     = true
  secondary_visualization = "None"
  time_range              = 172800

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }
  legend_options_fields {
    enabled  = true
    property = "BucketName"
  }

  viz_options {
    display_name = "Bucket size"
    label        = "A"
    value_unit   = "Byte"
  }
}

resource "signalfx_list_chart" "object_count" {
  name        = "Most objects by control-plane bucket"
  description = "Latest object count for Forge S3 buckets without TenantName."

  program_text = "A = data('NumberOfObjects', filter=(${local.control_plane_filter}) and (${local.s3_dimension_filter}) and filter('StorageType', 'AllStorageTypes') and filter('stat', 'mean'), rollup='latest').max(by=['aws_region', 'BucketName']).top(count=20).publish(label='A')"
  sort_by      = "-value"

  disable_sampling        = true
  hide_missing_values     = true
  secondary_visualization = "None"
  time_range              = 172800

  legend_options_fields {
    enabled  = true
    property = "aws_region"
  }
  legend_options_fields {
    enabled  = true
    property = "BucketName"
  }

  viz_options {
    display_name = "Objects"
    label        = "A"
  }
}

resource "signalfx_time_chart" "storage_by_class" {
  name        = "Control-plane S3 storage by class"
  description = "Daily S3 storage bytes by storage class for Forge buckets without TenantName."

  program_text = "A = data('BucketSizeBytes', filter=(${local.control_plane_filter}) and (${local.s3_dimension_filter}) and filter('stat', 'mean'), rollup='latest').sum(by=['StorageType']).publish(label='A')"

  plot_type                 = "AreaChart"
  axes_precision            = 0
  disable_sampling          = true
  on_chart_legend_dimension = "StorageType"
  stacked                   = true
  time_range                = 172800

  axis_left {
    label     = "Bytes"
    min_value = 0
  }

  legend_options_fields {
    enabled  = true
    property = "StorageType"
  }

  viz_options {
    display_name = "Storage"
    label        = "A"
    value_unit   = "Byte"
  }
}

resource "terraform_data" "dashboard_parent" {
  triggers_replace = var.dashboard_group
}

resource "signalfx_dashboard" "s3_control_plane" {
  name            = "Forge Control Plane - S3"
  description     = "Storage inventory for Forge S3 buckets that are not assigned to a tenant. S3 storage metrics are emitted daily."
  dashboard_group = var.dashboard_group
  time_range      = "-2d"

  lifecycle {
    replace_triggered_by = [
      terraform_data.dashboard_parent,
    ]
  }

  dynamic "variable" {
    for_each = var.dynamic_variables
    iterator = var_def

    content {
      property               = var_def.value.property
      alias                  = var_def.value.alias
      description            = var_def.value.description
      values                 = var_def.value.values
      value_required         = var_def.value.value_required
      values_suggested       = var_def.value.values_suggested
      restricted_suggestions = var_def.value.restricted_suggestions
    }
  }

  chart {
    chart_id = signalfx_single_value_chart.active_buckets.id
    row      = 0
    column   = 0
    width    = 12
    height   = 1
  }

  chart {
    chart_id = signalfx_list_chart.bucket_size.id
    row      = 1
    column   = 0
    width    = 6
    height   = 2
  }

  chart {
    chart_id = signalfx_list_chart.object_count.id
    row      = 1
    column   = 6
    width    = 6
    height   = 2
  }

  chart {
    chart_id = signalfx_time_chart.storage_by_class.id
    row      = 3
    column   = 0
    width    = 12
    height   = 1
  }
}
