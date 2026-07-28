output "detector_id" {
  description = "AWS regional platform detector ID for linking queue-health charts."
  value       = signalfx_detector.aws_regional_platform_health.id
}

output "lambda_control_plane_detector_id" {
  description = "AWS Lambda control-plane detector ID for linking Lambda health charts."
  value       = signalfx_detector.aws_control_plane_health.id
}

output "sqs_control_plane_detector_id" {
  description = "AWS SQS control-plane detector ID for linking SQS health charts."
  value       = signalfx_detector.aws_sqs_control_plane_health.id
}

output "runner_log_delivery_detector_id" {
  description = "Runner-log delivery integrity detector ID."
  value       = signalfx_detector.runner_log_delivery_health.id
}
