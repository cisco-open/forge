locals {
  runner_settings = {
    linux_small = {
      labels      = ["self-hosted", "linux", "x64", "forge", "size:small"]
      min_runners = 0
      max_runners = 10
    }
  }
}
