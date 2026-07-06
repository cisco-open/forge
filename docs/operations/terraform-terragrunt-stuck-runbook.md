# Terraform/Terragrunt Stuck Runbook

Use this helper when `terraform`, `tofu`, or `terragrunt` stops printing progress
during `plan` or `apply`.

Do not assume the last stdout line is the blocker. The provider can be retrying
an AWS API while unrelated resources wait in the graph.

## 1. Capture TRACE Logs

Run from the stack directory. Default to `plan`; set `TF_COMMAND=apply` only when
you intentionally want to apply. Replace `terragrunt` with `tofu` or
`terraform` if running without Terragrunt.

```bash
export TF_COMMAND="${TF_COMMAND:-plan}"
export TS="$(date +%Y%m%d-%H%M%S)"
export TF_TRACE="/private/tmp/forge-${TF_COMMAND}-trace-${TS}.log"
export TF_STDOUT="/private/tmp/forge-${TF_COMMAND}-stdout-${TS}.log"

TF_LOG=TRACE \
TF_LOG_PATH="$TF_TRACE" \
TG_LOG_LEVEL=trace \
terragrunt "$TF_COMMAND" 2>&1 | tee "$TF_STDOUT"
```

Let the command sit for a minute after it looks stuck so provider retries are
written to the trace.

## 2. Search For Common AWS And Wait Signals

```bash
rg -n "RequestLimitExceeded|Throttl|RequestTimeout|retrying request|http.status_code=5|Waiting for state lock|Acquiring state lock|local-exec|Still reading|Still creating|Still modifying" "$TF_TRACE"
tail -n 120 "$TF_STDOUT"
```

| Signal                                                 | Meaning                                                     |
| ------------------------------------------------------ | ----------------------------------------------------------- |
| `Waiting for state lock` or `Acquiring state lock`     | Backend lock wait; check the lock owner first.              |
| `local-exec`, `kubectl`, `helm`, or hook output        | Local command wait; debug that command directly.            |
| `RequestLimitExceeded`, `Throttling`, `RequestTimeout` | AWS API throttling or instability may be the real blocker.  |
| `http.status_code=5` or `operational issue`            | Check AWS Health before changing Terraform code.            |
| No obvious signal                                      | Inspect provider TRACE lines near the last graph operation. |

## 3. Check AWS Health Dashboard

If the trace points to AWS throttling, timeouts, HTTP `5xx`, or an AWS
operational issue, check the AWS Health Dashboard for the affected account,
Region, and service:

```text
https://health.aws.amazon.com/health/home
```

Look for open or recent events matching the API in the trace. For example, if
the trace shows `EC2/DescribeLaunchTemplates`, check EC2 and EKS health in that
Region before investigating EKS, Karpenter, or module code.

If AWS Health confirms an incident, pause code changes, attach the health event
and TRACE evidence to the incident, and retry after AWS mitigation.

## 4. Optional AWS Health API Check

The dashboard is the default check. The AWS Health API is useful for automation,
but it requires the account to have a qualifying AWS Support plan. Without that,
the API returns `SubscriptionRequiredException`.

```bash
aws health describe-events \
  --region us-east-1 \
  --filter "services=EC2,EKS,regions=us-east-1,global,eventStatusCodes=open,upcoming,eventTypeCategories=issue" \
  --output table
```

If an event matches the trace, get the detailed message:

```bash
aws health describe-event-details \
  --region us-east-1 \
  --event-arns "$HEALTH_EVENT_ARN" \
  --output yaml
```

Minimum useful IAM actions:

- `health:DescribeEvents`
- `health:DescribeEventDetails`
- `health:DescribeAffectedEntities`

## 5. Keep Minimal Evidence

- Stack path and command: `plan` or `apply`.
- Account and Region from `aws sts get-caller-identity`.
- TRACE log path and stdout log path.
- First repeated AWS API call or state-lock message.
- AWS Health Dashboard event title, Region, service, and timestamp if present.

## 6. Go Deeper Only If Needed

If AWS Health is clean but the trace still shows the same AWS API retry, then
check API usage and callers for that exact API with CloudWatch Usage and
CloudTrail. Do this after the trace identifies the service and API action, not
before.
