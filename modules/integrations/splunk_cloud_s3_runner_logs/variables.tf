variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "logging_retention_in_days" {
  description = "Log retention period in days"
  type        = number
  default     = 3
}

variable "log_level" {
  type        = string
  description = "Log level for application logging (e.g., INFO, DEBUG, WARN, ERROR)"
  default     = "INFO"
}

variable "lambda_event_source_mapping_maximum_concurrency" {
  description = "Maximum concurrent Lambda invocations for the runner-log SQS event source mapping."
  type        = number
  default     = 40

  validation {
    condition = (
      var.lambda_event_source_mapping_maximum_concurrency >= 2
      && var.lambda_event_source_mapping_maximum_concurrency <= 1000
      && floor(var.lambda_event_source_mapping_maximum_concurrency) == var.lambda_event_source_mapping_maximum_concurrency
    )
    error_message = "lambda_event_source_mapping_maximum_concurrency must be an integer between 2 and 1000."
  }
}

variable "sqs_redrive_max_receive_count" {
  description = "Number of source-queue receives allowed before a runner-log message moves to the DLQ."
  type        = number
  default     = 100

  validation {
    condition = (
      var.sqs_redrive_max_receive_count >= 1
      && floor(var.sqs_redrive_max_receive_count) == var.sqs_redrive_max_receive_count
    )
    error_message = "sqs_redrive_max_receive_count must be a positive integer."
  }
}

variable "splunk_hec_endpoint" {
  description = "Full URL of Splunk HEC endpoint"
  type        = string
}
