resource "helm_release" "managed_prometheus" {
  name             = "prometheus"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus"
  version          = "29.14.0"
  namespace        = "prometheus-system"
  create_namespace = true

  set = [
    {
      name  = "alertmanager.enabled"
      value = false
    },
    {
      name  = "prometheus-pushgateway.enabled"
      value = false
    },
    {
      name  = "server.persistentVolume.enabled"
      value = false
    },
    {
      name  = "server.service.servicePort"
      value = 80
    },
    {
      name  = "extraScrapeConfigs"
      value = <<-EOT
      - job_name: opencost
        honor_labels: true
        scrape_interval: 1m
        scrape_timeout: 10s
        metrics_path: /metrics
        scheme: http
        dns_sd_configs:
          - names:
              - opencost.opencost
            type: A
            port: 9003
      EOT
      type  = "string"
    }
  ]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 1200
  wait            = true

}

resource "helm_release" "opencost" {
  name             = "opencost"
  repository       = "https://opencost.github.io/opencost-helm-chart"
  chart            = "opencost"
  version          = "2.5.25"
  namespace        = "opencost"
  create_namespace = true

  set = [
    {
      name  = "fullnameOverride"
      value = "opencost"
    },
    {
      name  = "serviceAccount.create"
      value = true
    },
    {
      name  = "serviceAccount.name"
      value = "opencost"
    },
    {
      name  = "opencost.cloudIntegrationSecret"
      value = ""
    },
    {
      name  = "opencost.cloudCost.enabled"
      value = false
    },
    {
      name  = "opencost.exporter.apiPort"
      value = 9003
    },
    {
      name  = "opencost.exporter.defaultClusterId"
      value = var.cluster_name
    },
    {
      name  = "opencost.metrics.kubeStateMetrics.emitKsmV1Metrics"
      value = false
    },
    {
      name  = "opencost.metrics.kubeStateMetrics.emitKsmV1MetricsOnly"
      value = false
    },
    {
      name  = "opencost.prometheus.external.enabled"
      value = false
    },
    {
      name  = "opencost.prometheus.external.url"
      value = ""
    },
    {
      name  = "opencost.prometheus.internal.enabled"
      value = true
    },
    {
      name  = "opencost.prometheus.internal.namespaceName"
      value = "prometheus-system"
    },
    {
      name  = "opencost.prometheus.internal.serviceName"
      value = "prometheus-server"
    },
    {
      name  = "opencost.prometheus.internal.port"
      value = 80
    },
    {
      name  = "opencost.prometheus.internal.path"
      value = ""
    },
    {
      name  = "opencost.prometheus.internal.scheme"
      value = "http"
    },
    {
      name  = "opencost.ui.enabled"
      value = false
    },
    {
      name  = "podAnnotations.prometheus\\.io/scrape"
      value = "true"
      type  = "string"
    },
    {
      name  = "podAnnotations.prometheus\\.io/path"
      value = "/metrics"
      type  = "string"
    },
    {
      name  = "podAnnotations.prometheus\\.io/port"
      value = "9003"
      type  = "string"
    },
    {
      name  = "service.annotations.prometheus\\.io/scrape"
      value = "true"
      type  = "string"
    },
    {
      name  = "service.annotations.prometheus\\.io/path"
      value = "/metrics"
      type  = "string"
    },
    {
      name  = "service.annotations.prometheus\\.io/port"
      value = "9003"
      type  = "string"
    }
  ]

  atomic          = true
  cleanup_on_fail = true
  timeout         = 1200
  wait            = true

  depends_on = [
    helm_release.managed_prometheus,
  ]
}
