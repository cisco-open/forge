variable "aws_profile" {
  description = "AWS profile to use."
  type        = string
}

variable "aws_region" {
  description = "Default AWS region."
  type        = string
}

variable "default_tags" {
  description = "A map of tags to apply to resources."
  type        = map(string)
}

variable "tags" {
  description = "A map of additional tags to apply to resources."
  type        = map(string)
}

variable "host_groups" {
  description = "Map of host groups, each with a name, host instance type, and a list of hosts."
  type = map(object({
    name               = string
    host_instance_type = string
    hosts = list(object({
      name              = string
      availability_zone = string
    }))
  }))

  validation {
    condition = length(distinct([
      for group in values(var.host_groups) : group.name
    ])) == length(var.host_groups)
    error_message = "Each host group must have a unique name."
  }
}
