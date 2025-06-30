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

variable "cluster_size" {
  description = "The size config of the EKS cluster"
  type = object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  })
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
