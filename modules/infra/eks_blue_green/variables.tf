variable "aws_profile" {
  type        = string
  description = "AWS profile to use."
}

variable "aws_region" {
  type        = string
  description = "Default AWS region."
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

variable "clusters" {
  type = object({
    blue = object({
      cluster_name    = string
      cluster_version = string
      cluster_size = object({
        instance_type = string
        min_size      = number
        max_size      = number
        desired_size  = number
      })
      cluster_volume = object({
        size       = number
        iops       = number
        throughput = number
        type       = string
      })
      subnet_ids         = list(string)
      vpc_id             = string
      cluster_ami_filter = list(string)
      cluster_ami_owners = list(string)
    })
    green = object({
      cluster_name    = string
      cluster_version = string
      cluster_size = object({
        instance_type = string
        min_size      = number
        max_size      = number
        desired_size  = number
      })
      cluster_volume = object({
        size       = number
        iops       = number
        throughput = number
        type       = string
      })
      subnet_ids         = list(string)
      vpc_id             = string
      cluster_ami_filter = list(string)
      cluster_ami_owners = list(string)
    })
  })
}
