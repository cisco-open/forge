# terragrunt-ministack.hcl
#
# Cole este bloco `generate` no seu terragrunt.hcl raiz (root config).
# Ele so cria o override quando USE_MINISTACK=true, entao nunca afeta um apply
# real. O nome do arquivo gerado termina em _override.tf -> mescla no provider.
#
# Uso:  USE_MINISTACK=true terragrunt plan
#       (sem a env var, o bloco fica desligado e o Terragrunt ignora o MiniStack)

generate "ministack" {
  path      = "ministack_override.tf"
  if_exists = "overwrite"
  disable   = get_env("USE_MINISTACK", "false") != "true"

  contents = <<-EOF
    provider "aws" {
      access_key                  = "test"
      secret_key                  = "test"
      region                      = "us-east-1"
      skip_credentials_validation = true
      skip_metadata_api_check     = true
      skip_requesting_account_id  = true
      s3_use_path_style           = true

      endpoints {
        s3          = "http://localhost:4566"
        sqs         = "http://localhost:4566"
        sns         = "http://localhost:4566"
        ssm         = "http://localhost:4566"
        iam         = "http://localhost:4566"
        sts         = "http://localhost:4566"
        lambda      = "http://localhost:4566"
        events      = "http://localhost:4566"
        logs        = "http://localhost:4566"
        cloudwatch  = "http://localhost:4566"
        kms         = "http://localhost:4566"
        ec2         = "http://localhost:4566"
        autoscaling = "http://localhost:4566"
        dynamodb    = "http://localhost:4566"
        eks         = "http://localhost:4566"
      }
    }
  EOF
}
