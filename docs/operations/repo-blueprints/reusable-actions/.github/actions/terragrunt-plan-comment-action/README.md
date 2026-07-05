# Terragrunt Plan Comment Action

Composite GitHub Action that posts a formatted Terragrunt plan as a comment on a pull request. It wraps a forked Terraform plan comment action while forcing Terragrunt execution semantics.

## What It Does

1. Runs with `terraform-cmd: terragrunt` in the specified working directory (`working-directory`).
1. Reads the provided binary plan file (`planfile`).
1. Generates a markdown summary.
1. Posts (or optionally skips) a PR comment when changes are detected.

## Inputs

| Name                | Required | Default | Description                                                                       |
| ------------------- | -------- | ------- | --------------------------------------------------------------------------------- |
| `working-directory` | yes      | n/a     | Path to Terragrunt root where plan was generated. Used as comment header context. |
| `planfile`          | yes      | n/a     | Path to the plan file created earlier (binary format).                            |
| `skip-empty`        | yes      | `true`  | If `true`, no comment is posted when the plan has no resource changes.            |
| `skip-comment`      | yes      | `false` | If `true`, always skip posting the comment (useful for dry runs).                 |

## Environment Variables (Internal)

The action sets:

- `TG_NO_COLOR=true` (strips ANSI color codes)
- `TG_TF_FORWARD_STDOUT=true` (ensures Terragrunt forwards Terraform output)

You generally do not need to override these.

## Outputs

This composite action currently does not emit formal outputs. The PR comment is the side-effect.

## Requirements

- A prior step must have executed a Terragrunt plan and produced a plan file.
- `terragrunt` must be on the PATH of the runner.
- The workflow must have `pull_request` or `pull_request_target` context with permission to comment.

## Example Usage

```yaml
jobs:
	plan:
		runs-on: ubuntu-latest
		steps:
			- uses: actions/checkout@v5

			- name: Setup Terragrunt (example)
				run: |
					brew install tgenv && tgenv install latest && tgenv use latest

			- name: Generate plan
				run: |
					cd terraform/environments/dev
					terragrunt plan -out plan.tfplan

			- name: Comment plan
				uses: your-org/forge-reusable-actions/.github/actions/terragrunt-plan-comment-action@<commit-sha>
				with:
					working-directory: terraform/environments/dev
					planfile: terraform/environments/dev/plan.tfplan
					skip-empty: 'true'
					skip-comment: 'false'
```

## Skip Behavior

- If `skip-empty: 'true'` and the plan has no changes, the comment is suppressed.
- If `skip-comment: 'true'`, the action always suppresses posting regardless of the plan contents.

## Troubleshooting

| Symptom                      | Cause                                   | Fix                                                      |
| ---------------------------- | --------------------------------------- | -------------------------------------------------------- |
| No comment appears           | Empty plan and `skip-empty` true        | Set `skip-empty: 'false'` to always post summary         |
| No comment, plan has changes | Missing PR context (workflow not on PR) | Ensure job runs on `pull_request` event                  |
| Action fails parsing plan    | Incorrect `planfile` path / not binary  | Use exact path produced by `terragrunt plan -out <file>` |
| Terragrunt not found         | Not installed before action             | Install Terragrunt earlier in workflow                   |
