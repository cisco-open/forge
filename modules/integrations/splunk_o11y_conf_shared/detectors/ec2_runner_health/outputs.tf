output "detector_ids" {
  description = "Forge EC2 runner health detector IDs for dashboard alert overlays."
  value = {
    cpu    = signalfx_detector.ec2_runner_cpu.id
    disk   = signalfx_detector.ec2_runner_disk.id
    memory = signalfx_detector.ec2_runner_memory.id
  }
}
