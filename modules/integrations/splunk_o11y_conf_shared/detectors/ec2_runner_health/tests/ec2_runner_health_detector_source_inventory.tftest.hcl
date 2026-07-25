run "ec2_runner_health_detector_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_detector\" \"ec2_runner_cpu\"",
      "resource \"signalfx_detector\" \"ec2_runner_disk\"",
      "resource \"signalfx_detector\" \"ec2_runner_memory\"",
      "^aws.ec2.cpu.utilization",
      "system.filesystem.usage",
      "system.memory.usage",
      "filter('type', 'ext4', 'xfs')",
      "auto_resolve_after='15m'",
      "__forge_tenant_scope_not_configured__",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "The EC2 runner health detector source inventory is incomplete."
  }

  assert {
    condition     = output.expected_literal_count == 9
    error_message = "The EC2 runner health detector source inventory count must remain pinned."
  }
}
