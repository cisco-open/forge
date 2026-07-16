resource "aws_iam_role" "config" {
  name               = local.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.config_assume_role.json
  tags               = local.all_security_tags
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

resource "aws_config_configuration_recorder" "this" {
  #checkov:skip=CKV2_AWS_45:Selective recording is intentional; callers supply recorded_resource_types.
  #checkov:skip=CKV2_AWS_48:Global resources are recorded only when explicitly selected by the caller.
  name     = var.recorder_name
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported  = false
    resource_types = sort(tolist(var.recorded_resource_types))

    recording_strategy {
      use_only = "INCLUSION_BY_RESOURCE_TYPES"
    }
  }

  recording_mode {
    recording_frequency = "CONTINUOUS"
  }

  depends_on = [aws_iam_role_policy_attachment.config]
}

resource "aws_config_delivery_channel" "this" {
  name           = var.delivery_channel_name
  s3_bucket_name = var.delivery_bucket_name

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}
