run "integrations_splunk_o11y_conf_shared_dashboards_sqs_source_inventory" {
  command = plan

  module {
    source = "../../../../../tests/tofu/module_contract"
  }

  variables {
    module_path = "."
    expected_literals = [
      "resource \"signalfx_single_value_chart\" \"queues\"",
      "resource \"signalfx_list_chart\" \"top_queues_by_message_sent\"",
      "resource \"signalfx_time_chart\" \"sent_message_size\"",
      "resource \"signalfx_time_chart\" \"messages_by_state\"",
      "resource \"signalfx_list_chart\" \"oldest_message_age\"",
      "resource \"signalfx_time_chart\" \"empty_receives\"",
      "resource \"signalfx_list_chart\" \"top_queues_by_message_received\"",
      "resource \"signalfx_time_chart\" \"message_processing_trend\"",
      "resource \"signalfx_time_chart\" \"messages_deleted\"",
      "resource \"signalfx_time_chart\" \"dead_letter_backlog_trend\"",
      "resource \"signalfx_list_chart\" \"dead_letter_oldest_message_age\"",
      "resource \"signalfx_list_chart\" \"dead_letter_visible_messages\"",
      "resource \"signalfx_dashboard\" \"sqs\"",
    ]
  }

  assert {
    condition     = length(output.missing_expected_literals) == 0
    error_message = "Source inventory is missing expected Terraform blocks: ${join(", ", output.missing_expected_literals)}"
  }

  assert {
    condition     = output.expected_literal_count == 13
    error_message = "Source inventory must keep 13 module-specific Terraform blocks pinned."
  }
}
