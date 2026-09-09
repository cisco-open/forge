variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "The version of the EKS cluster"
  type        = string
}

variable "cluster_endpoint_public_access" {
  description = "Whether the EKS cluster endpoint is publicly accessible"
  type        = bool
  default     = false
}

variable "external_access_cidr_blocks" {
  description = "External CIDR Blocks to access k8s api"
  type        = list(string)
  default     = []
}

variable "cluster_size" {
  description = "The size config of the EKS cluster"
  type = object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  })
}

variable "karpenter_node_pool" {
  description = "Configuration for the Karpenter NodePool."
  type = object({
    instance_families    = optional(list(string), ["m6i", "m5", "c6i", "c5", "r6i", "r5"])
    architectures        = optional(list(string), ["amd64"])
    operating_systems    = optional(list(string), ["linux"])
    capacity_types       = optional(list(string), ["on-demand"])
    cpu_limit            = optional(number, 1000)
    consolidation_policy = optional(string, "WhenEmptyOrUnderutilized")
    consolidate_after    = optional(string, "1m")
  })
  default = {}
}

variable "runner_reaper" {
  description = "Cluster-wide remediation for ARC runners that are stuck after accepting a job. When enabled, it discovers and covers every ARC tenant by default. Dry-run remains the default and active deletion requires a digest-pinned image."
  type = object({
    enabled                     = optional(bool, false)
    dry_run                     = optional(bool, true)
    namespace                   = optional(string, "forge-system")
    schedule                    = optional(string, "*/15 * * * *")
    stale_after_seconds         = optional(number, 900)
    confirmation_delay_seconds  = optional(number, 60)
    max_probes_per_namespace    = optional(number, 50)
    max_probes_per_run          = optional(number, 500)
    max_deletions_per_namespace = optional(number, 1)
    max_deletions_per_run       = optional(number, 20)
    image                       = optional(string)
  })
  default = {}

  validation {
    condition = (
      var.runner_reaper.stale_after_seconds >= 720
      && var.runner_reaper.stale_after_seconds <= 86400
      && floor(var.runner_reaper.stale_after_seconds) == var.runner_reaper.stale_after_seconds
    )
    error_message = "runner_reaper.stale_after_seconds must be a whole number between 720 and 86400 so the reaper cannot act before GitHub's 10-minute lost-contact timeout."
  }

  validation {
    condition = (
      var.runner_reaper.confirmation_delay_seconds >= 30
      && var.runner_reaper.confirmation_delay_seconds <= 300
      && floor(var.runner_reaper.confirmation_delay_seconds) == var.runner_reaper.confirmation_delay_seconds
    )
    error_message = "runner_reaper.confirmation_delay_seconds must be a whole number between 30 and 300."
  }

  validation {
    condition = (
      var.runner_reaper.max_probes_per_namespace >= 1
      && var.runner_reaper.max_probes_per_namespace <= 200
      && floor(var.runner_reaper.max_probes_per_namespace) == var.runner_reaper.max_probes_per_namespace
    )
    error_message = "runner_reaper.max_probes_per_namespace must be a whole number between 1 and 200."
  }

  validation {
    condition = (
      var.runner_reaper.max_probes_per_run >= var.runner_reaper.max_probes_per_namespace
      && var.runner_reaper.max_probes_per_run <= 2000
      && floor(var.runner_reaper.max_probes_per_run) == var.runner_reaper.max_probes_per_run
    )
    error_message = "runner_reaper.max_probes_per_run must be a whole number between max_probes_per_namespace and 2000."
  }

  validation {
    condition = (
      var.runner_reaper.max_deletions_per_namespace >= 1
      && var.runner_reaper.max_deletions_per_namespace <= 5
      && floor(var.runner_reaper.max_deletions_per_namespace) == var.runner_reaper.max_deletions_per_namespace
    )
    error_message = "runner_reaper.max_deletions_per_namespace must be a whole number between 1 and 5."
  }

  validation {
    condition = (
      var.runner_reaper.max_deletions_per_run >= var.runner_reaper.max_deletions_per_namespace
      && var.runner_reaper.max_deletions_per_run <= 100
      && floor(var.runner_reaper.max_deletions_per_run) == var.runner_reaper.max_deletions_per_run
    )
    error_message = "runner_reaper.max_deletions_per_run must be a whole number between max_deletions_per_namespace and 100."
  }

  validation {
    condition = (
      length(var.runner_reaper.namespace) <= 63
      && can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.runner_reaper.namespace))
    )
    error_message = "runner_reaper.namespace must be a valid Kubernetes DNS label of at most 63 characters."
  }

  validation {
    condition     = trimspace(var.runner_reaper.schedule) != ""
    error_message = "runner_reaper.schedule must not be empty."
  }

  validation {
    condition = (
      !var.runner_reaper.enabled
      || try(trimspace(var.runner_reaper.image) != "", false)
    )
    error_message = "Enabled runner reaping requires a shell-capable kubectl image."
  }

  validation {
    condition = (
      !var.runner_reaper.enabled
      || var.runner_reaper.dry_run
      || can(regex("@sha256:[0-9a-fA-F]{64}$", coalesce(var.runner_reaper.image, "unpinned")))
    )
    error_message = "Active runner reaping requires runner_reaper.image to be pinned by sha256 digest."
  }
}

variable "cluster_volume" {
  description = "The volume config of the EKS cluster"
  type = object({
    size       = number
    iops       = number
    throughput = number
    type       = string
  })
}

variable "subnet_ids" {
  description = "A list of private subnet IDs for worker nodes"
  type        = list(string)
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "cluster_tags" {
  type        = map(string)
  description = "Cluster tags"
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "default_tags" {
  type        = map(string)
  description = "A map of tags to apply to resources."
}

variable "cluster_ami_filter" {
  description = "The AWS account ID that owns the EKS cluster AMI."
  type        = list(string)
}

variable "cluster_ami_owners" {
  description = "The AWS account ID that owns the EKS cluster AMI."
  type        = list(string)
}

variable "cluster_admin_role_arn" {
  description = "Full ARN of IAM role for EKS cluster admin access."
  type        = string
  default     = ""
}
