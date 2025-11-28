resource "signalfx_dashboard_group" "forgecicd" {
  name        = "ForgeCICD Dashboards"
  description = ""
  teams       = [var.team]
}
