locals {
  cluster_name    = "forge-euw1-dev" # <REPLACE WITH YOUR VALUE>
  cluster_version = "1.31"           # <REPLACE WITH YOUR VALUE>
  cluster_size = {
    instance_type = "m5.large" # <REPLACE WITH YOUR VALUE>
    min_size      = 3          # <REPLACE WITH YOUR VALUE>
    max_size      = 10         # <REPLACE WITH YOUR VALUE>
    desired_size  = 3          # <REPLACE WITH YOUR VALUE>
  }
  subnet_ids = [
    "subnet-0abc1234def567890", # <REPLACE WITH YOUR VALUE>
    "subnet-0123456789abcdef0", # <REPLACE WITH YOUR VALUE>
  ]
  vpc_id = "vpc-0abc1234def567890" # <REPLACE WITH YOUR VALUE>
}
