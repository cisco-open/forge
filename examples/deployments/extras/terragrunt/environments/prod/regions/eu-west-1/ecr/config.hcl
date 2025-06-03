locals {
  # <REPLACE WITH YOUR VALUE>
  repositories = [
    {
      repo         = "pre-commit"
      mutability   = "MUTABLE"
      scan_on_push = true
    },
    {
      repo         = "ops-builder"
      mutability   = "MUTABLE"
      scan_on_push = true
    },
    {
      repo         = "actions-runner"
      mutability   = "MUTABLE"
      scan_on_push = true
    },
    {
      repo         = "actions-runner-base-image"
      mutability   = "MUTABLE"
      scan_on_push = true
    },
  ]
}
