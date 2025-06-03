# We use for enabling safety hooks. They're in place to prevent an accident "tf
# run-all apply" for a non-dev environment.
terraform {
  # Make it difficult to change or destroy resources in non-dev environments.
  before_hook "before_hook" {
    commands = ["apply", "plan", "destroy"]
    execute = [
      "/bin/bash", "-c",
      "${get_parent_terragrunt_dir()}/safety_hook.sh \"${get_parent_terragrunt_dir()}\" \"${get_terragrunt_dir()}\""
    ]
  }

  # Placeholder (no-op); might use this in the future.
  after_hook "after_hook" {
    commands     = ["apply", "plan"]
    execute      = ["/bin/bash", "-c", ":"]
    run_on_error = true
  }
}
