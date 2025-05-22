locals {
  cluster_name    = "forge-euw1-dev"
  cluster_version = "1.31"
  cluster_size = {
    instance_type = "m5.large"
    min_size      = 3
    max_size      = 10
    desired_size  = 3
  }
  subnet_ids = [
    "subnet-aaaaaaaaaaaaaaaaa",
    "subnet-bbbbbbbbbbbbbbbbb",
  ]
  vpc_id = "vpc-xxxxxxxxxxxxxxxxx"

  splunk_otel_collector = {
    splunk_observability_realm     = "us0"
    splunk_platform_endpoint       = "https://http-inputs-<your instance>.splunkcloud.com:443/services/collector"
    splunk_platform_index          = "forge-prod-index"
    gateway                        = false
    splunk_observability_profiling = true
    environment                    = "prod"
    discovery                      = true
  }
}
