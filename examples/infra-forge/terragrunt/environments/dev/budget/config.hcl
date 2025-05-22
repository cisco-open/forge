locals {
  # Budget/billing constraints.
  aws_budget = {
    # AWS uses strings, not numbers, in this API.
    per_account = "500.00"
    services = {
      EC2 = {
        budget_limit = "200.00"
      },
      S3 = {
        budget_limit = "200.00"
      },
    }
  }
}
