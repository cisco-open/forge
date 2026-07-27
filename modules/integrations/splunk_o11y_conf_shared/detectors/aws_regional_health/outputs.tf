output "detector_id" {
  description = "AWS regional platform detector ID for linking queue-health charts."
  value       = signalfx_detector.aws_regional_platform_health.id
}

output "control_plane_detector_id" {
  description = "AWS control-plane detector ID for shared Lambda and SQS health."
  value       = signalfx_detector.aws_control_plane_health.id
}
