locals {
  vpc_alias = "sl" # <REPLACE WITH YOUR VALUE>

  # Subnet IDs for Lambda functions
  lambda_subnet_ids = ["subnet-0abc1234def567890"] # <REPLACE WITH YOUR VALUE>

  vpc_id = "vpc-0abc1234def567890" # <REPLACE WITH YOUR VALUE>
  subnet_ids = [
    "subnet-0abc1234def567890", # <REPLACE WITH YOUR VALUE>
    "subnet-0123456789abcdef0", # <REPLACE WITH YOUR VALUE>
  ]
  cluster_name = "forge-euw1-prod" # <REPLACE WITH YOUR VALUE>
}
