# Tenant dependency-probe detectors

Creates one Splunk Observability detector per Forge tenant. Each detector has
rules for:

- missing probe telemetry;
- unavailable regional SSM GitHub App parameters;
- failed GitHub App authentication or organization runner API access; and
- low GitHub REST API rate-limit budget.

The detector keeps `AWSRegion` in the output MTS so a tenant
incident identifies the affected Forge deployment region.
