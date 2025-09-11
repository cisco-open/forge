# Building the GitHub Actions Base Image with Packer

This guide explains how to build the Forge GitHub Actions runner base image using [Packer](https://www.packer.io/).

## Prerequisites

- [Packer](https://www.packer.io/downloads) installed
- AWS CLI configured with credentials and permissions to build AMIs
- The required VPC and subnet exist in your AWS account
- (Optional) Splunk Observability credentials if you want to enable Splunk OTel Collector
- (Optional) Teleport for secure SSH access

## Required Variables

You must provide the following variables to Packer:

- `subnet_id`: The subnet where the instance will be launched
- `vpc_id`: The VPC where the instance will be launched
- `allowed_ssh_cidrs`: CIDR blocks allowed to SSH into the instance (for debugging)
- `aws_region`: The AWS region to build the image in

Example values:

- `subnet_id=subnet-0123456789abcdef0`
- `vpc_id=vpc-0123456789abcdef0`
- `allowed_ssh_cidrs=10.0.0.0/8`
- `aws_region=us-west-2`

## (Optional) Splunk OTel Collector and Teleport

If you want to include the Splunk OpenTelemetry Collector in your image, set the following environment variables **before** running Packer:

```sh
export SPLUNK_ACCESS_TOKEN=<your_splunk_access_token>
export SPLUNK_REALM=<your_splunk_realm>
```

If you want to include Teleport or Splunk OTel Collector roles in the build, enable them in your Ansible playbook by uncommenting the roles:

`forge/examples/build/ansible/build_gh_base_image.yaml`

```yaml
roles:
  - role: teleport  
  - role: splunk_otel_collector
```

## Build Command

Run the following command from the directory containing your Packer template:

```sh
cd forge/examples/build/packer
packer build \
  -var "subnet_id=<your_subnet_id>" \
  -var "vpc_id=<your_vpc_id>" \
  -var "allowed_ssh_cidrs=<your_allowed_ssh_cidrs>" \
  -var "aws_region=<your_aws_region>" \
  .
```

**Example:**

```sh
cd forge/examples/build/packer
packer build \
  -var "subnet_id=subnet-0123456789abcdef0" \
  -var "vpc_id=vpc-0123456789abcdef0" \
  -var "allowed_ssh_cidrs=10.0.0.0/8" \
  -var "aws_region=us-west-2" \
  .
```

## Notes

- Make sure your AWS user/role has permissions to create EC2 instances, AMIs, and related resources.
- If you enable the Splunk OTel Collector, ensure your access token and realm are valid.
- The resulting AMI can be used as the base image for Forge GitHub Actions runners.
