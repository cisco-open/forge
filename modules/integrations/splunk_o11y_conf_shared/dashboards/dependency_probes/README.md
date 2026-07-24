# Forge external dependency health dashboard

This module provisions the Splunk Observability dashboard backed by metrics
sent directly from the regional dependency-monitor Lambda.

It presents tenant- and region-level views for:

- GitHub App authentication and organization runner API availability.
- AWS SSM parameter access.
- GitHub API rate-limit budget.
- Dependency check latency.
- Scheduled regional probe telemetry.

The dashboard is created in the shared Forge dashboard group. Its tenant
selector and metric scope come only from
`dashboard_variables.dependency_probes.tenant_names`; its dynamic variables
come only from `dashboard_variables.dependency_probes.dynamic_variables`.
