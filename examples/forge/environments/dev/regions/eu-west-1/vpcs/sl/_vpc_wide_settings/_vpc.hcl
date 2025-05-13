locals {
  vpc_alias = "sl"

  # Subnet IDs for Lambda functions
  lambda_subnet_ids = ["subnet-xxxxxxxxxxxxxxxxx"]

  vpc_id = "vpc-xxxxxxxxxxxxxxxxx"
  subnet_ids = [
    "subnet-yyyyyyyyyyyyyyyyy",
    "subnet-xxxxxxxxxxxxxxxxx",
  ]
  cluster_name = "forge-euw1-dev" # Replace with the eks cluster name
}
