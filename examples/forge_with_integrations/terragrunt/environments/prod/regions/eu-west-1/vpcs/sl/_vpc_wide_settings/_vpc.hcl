locals {
  vpc_alias = "<ADD YOUR VALUE>" # e.g., "sl"

  # Subnet IDs for Lambda functions
  lambda_subnet_ids = ["<ADD YOUR VALUE>"] # e.g., "subnet-0abc1234def567890"

  vpc_id = "<ADD YOUR VALUE>" # e.g., "vpc-0abc1234def567890"
  subnet_ids = [
    "<ADD YOUR VALUE>", # e.g., "subnet-0abc1234def567890"
    "<ADD YOUR VALUE>", # e.g., "subnet-0123456789abcdef0"
  ]
  cluster_name = "<ADD YOUR VALUE>" # e.g., "forge-euw1-prod"
}
