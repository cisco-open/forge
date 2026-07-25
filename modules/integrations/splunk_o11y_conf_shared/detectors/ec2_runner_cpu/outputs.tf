output "detector_id" {
  description = "Forge EC2 runner CPU detector ID for dashboard alert overlays."
  value       = signalfx_detector.ec2_runner_cpu.id
}
