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

  # local-exec provisioners do not run for an in-place terraform_data
  # update, so stack, template, and tag changes must replace this resource.
  triggers_replace = [
    aws_cloudformation_stack.splunk_integration.id,
    var.template_url,
    sha256(jsonencode(local.all_security_tags)),
  ]

  # Apply all desired tags. Splunk creates its managed Metric Stream
  # asynchronously after the CloudFormation prerequisites are available.
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

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

    command = <<-EOT
      set -euo pipefail

      resolve_metric_stream_arn() {
        local matching_output
        local candidate_arn
        local -a matching_arns=()

        if ! matching_output="$(aws cloudwatch list-metric-streams \
          --region "$AWS_REGION" \
          --query "Entries[?starts_with(Name, '$STREAM_NAME_PREFIX')].Arn" \
          --output text)"; then
          return 2
        fi

        while IFS= read -r candidate_arn; do
          if [ -n "$candidate_arn" ] && [ "$candidate_arn" != "None" ]; then
            matching_arns+=("$candidate_arn")
          fi
        done < <(printf '%s\n' "$matching_output" | tr '\t' '\n')

        if [ "$${#matching_arns[@]}" -eq 0 ]; then
          return 1
        fi

        if [ "$${#matching_arns[@]}" -ne 1 ]; then
          echo "Expected exactly one CloudWatch Metric Stream with prefix '$STREAM_NAME_PREFIX'; found $${#matching_arns[@]}." >&2
          printf '  %s\n' "$${matching_arns[@]}" >&2
          return 2
        fi

        printf '%s\n' "$${matching_arns[0]}"
      }

      if [ "$TAG_COUNT" -eq 0 ]; then
        echo "No CloudWatch Metric Stream tags to apply."
        exit 0
      fi

      for ((attempt = 1; attempt <= 60; attempt++)); do
        resource_arn=""

        if resource_arn="$(resolve_metric_stream_arn)"; then
          echo "Applying $TAG_COUNT tag(s) to CloudWatch Metric Stream: $resource_arn"

          if output="$(aws cloudwatch tag-resource \
            --region "$AWS_REGION" \
            --resource-arn "$resource_arn" \
            --tags "$TAGS_JSON" 2>&1)"; then
            exit 0
          fi

          if [[ "$output" != *"ResourceNotFoundException"* ]]; then
            echo "$output" >&2
            exit 1
          fi
        else
          resolve_status="$?"
          if [ "$resolve_status" -ne 1 ]; then
            exit "$resolve_status"
          fi
        fi

        if [ "$attempt" -eq 60 ]; then
          echo "CloudWatch Metric Stream with prefix '$STREAM_NAME_PREFIX' was not available after 15 minutes." >&2
          exit 1
        fi

        echo "CloudWatch Metric Stream with prefix '$STREAM_NAME_PREFIX' is not available yet; retrying in 15 seconds."
        sleep 15
      done
    EOT
  }

  # Remove all keys managed by the previous instance of this helper.
  #
  # This runs when:
  # - a tag is deleted from local.all_security_tags;
  # - a tag value changes;
  # - the CloudFormation stack or template changes;
  # - terraform destroy is executed.
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]

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

    command = <<-EOT
      set -euo pipefail

      resolve_metric_stream_arn() {
        local matching_output
        local candidate_arn
        local -a matching_arns=()

        if ! matching_output="$(aws cloudwatch list-metric-streams \
          --region "$AWS_REGION" \
          --query "Entries[?starts_with(Name, '$STREAM_NAME_PREFIX')].Arn" \
          --output text)"; then
          return 2
        fi

        while IFS= read -r candidate_arn; do
          if [ -n "$candidate_arn" ] && [ "$candidate_arn" != "None" ]; then
            matching_arns+=("$candidate_arn")
          fi
        done < <(printf '%s\n' "$matching_output" | tr '\t' '\n')

        if [ "$${#matching_arns[@]}" -eq 0 ]; then
          return 1
        fi

        if [ "$${#matching_arns[@]}" -ne 1 ]; then
          echo "Expected exactly one CloudWatch Metric Stream with prefix '$STREAM_NAME_PREFIX'; found $${#matching_arns[@]}." >&2
          printf '  %s\n' "$${matching_arns[@]}" >&2
          return 2
        fi

        printf '%s\n' "$${matching_arns[0]}"
      }

      if [ "$TAG_COUNT" -eq 0 ]; then
        echo "No CloudWatch Metric Stream tags to remove."
        exit 0
      fi

      resource_arn=""

      if resource_arn="$(resolve_metric_stream_arn)"; then
        :
      else
        resolve_status="$?"

        if [ "$resolve_status" -eq 1 ]; then
          echo "CloudWatch Metric Stream no longer exists; no tags remain to remove."
          exit 0
        fi

        exit "$resolve_status"
      fi

      echo "Removing previously managed tags from CloudWatch Metric Stream: $resource_arn"

      if output="$(aws cloudwatch untag-resource \
        --region "$AWS_REGION" \
        --resource-arn "$resource_arn" \
        --tag-keys "$TAG_KEYS_JSON" 2>&1)"; then
        exit 0
      fi

      if [[ "$output" == *"ResourceNotFoundException"* ]]; then
        echo "CloudWatch Metric Stream no longer exists; no tags remain to remove."
        exit 0
      fi

      echo "$output" >&2
      exit 1
    EOT
  }

  depends_on = [
    aws_cloudformation_stack.splunk_integration,
  ]
}
