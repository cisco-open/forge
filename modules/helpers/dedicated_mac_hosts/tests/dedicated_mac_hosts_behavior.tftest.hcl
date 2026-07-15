mock_provider "aws" {}

variables {
  aws_profile = "test"
  aws_region  = "eu-west-1"
  default_tags = {
    Product = "Forge"
  }
  tags = {
    Env = "test"
  }
  host_groups = {
    mac2 = {
      name               = "mac2-servers"
      host_instance_type = "mac2.metal"
      hosts = [
        {
          name              = "mac2-server-1"
          availability_zone = "eu-west-1a"
        },
        {
          name              = "mac2-server-2"
          availability_zone = "eu-west-1b"
        },
      ]
    }
  }
}

run "dedicated_mac_hosts_contract" {
  command = plan

  assert {
    condition = (
      aws_ec2_host.mac_dedicated_host["mac2-mac2-server-1"].instance_type == "mac2.metal"
      && aws_ec2_host.mac_dedicated_host["mac2-mac2-server-1"].availability_zone == "eu-west-1a"
      && aws_ec2_host.mac_dedicated_host["mac2-mac2-server-1"].auto_placement == "on"
      && aws_ec2_host.mac_dedicated_host["mac2-mac2-server-1"].tags.Product == "Forge"
      && aws_ec2_host.mac_dedicated_host["mac2-mac2-server-1"].tags.Env == "test"
      && aws_ec2_host.mac_dedicated_host["mac2-mac2-server-1"].tags.HostGroup == "mac2-servers"
      && aws_resourcegroups_group.mac_host_group["mac2-servers"].name == "mac2-servers"
      && aws_licensemanager_license_configuration.mac_dedicated_host_license_configuration.license_counting_type == "Socket"
    )
    error_message = "Dedicated Mac Hosts must preserve host allocation, grouping, license configuration, and merged tags."
  }
}

run "rejects_duplicate_host_group_names" {
  command = plan

  variables {
    host_groups = {
      first = {
        name               = "duplicate"
        host_instance_type = "mac2.metal"
        hosts              = []
      }
      second = {
        name               = "duplicate"
        host_instance_type = "mac2.metal"
        hosts              = []
      }
    }
  }

  expect_failures = [var.host_groups]
}
