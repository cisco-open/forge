# Splunk Observability Kubernetes Control Plane Dashboard

This module creates cluster-scoped operational charts for the Kubernetes platform that hosts Forge ARC runners.

It keeps platform components such as Karpenter, networking controllers, Prometheus, and the Splunk OpenTelemetry Collector separate from tenant runner workloads. The dashboard covers configured platform namespace pod health, plus the common `monitoring`, `prometheus`, and `splunk-otel-collector` namespaces, node pressure, collector pod health, exporter queue utilization, and telemetry loss.
