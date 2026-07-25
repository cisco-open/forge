output "detector_id" {
  description = "AWS regional platform detector ID for linking queue-health charts."
  value       = signalfx_detector.aws_regional_platform_health.id
}
