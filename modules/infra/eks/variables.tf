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
