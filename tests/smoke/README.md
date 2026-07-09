# Forge Smoke Tests

## What This Is

`tests/smoke` contains shallow MiniStack checks that answer whether Forge's
AWS-like plumbing is alive and wired. They use dummy credentials against a local
MiniStack emulator on `http://localhost:4566`.

## Why It Is Used

These are not correctness tests. They catch broken service wiring and emulator
compatibility for S3, SQS + DLQ, SSM SecureString, EventBridge, CloudWatch Logs,
STS identity, IAM role create/assume mechanics, and selected real Lambda
execution paths.

## CI Execution

The `MiniStack Smoke` workflow runs this suite when Lambda code, smoke tests, or
the workflow itself changes. CI starts MiniStack with Docker Compose, waits for
STS readiness, then runs:

```bash
uv run --project ../.. --locked --only-group smoke-tests pytest -m smoke -q
uv run --project ../.. --locked --only-group smoke-tests pytest -m lambda_exec -q
```

CI sets `FORGE_REQUIRE_MINISTACK=1`, so an unreachable emulator fails the job
instead of skipping. The STS role-chain check creates and assumes a dummy IAM
role inside MiniStack; it does not require a live AWS role or repository secret.

## Local Execution

From this directory:

```bash
make up        # start MiniStack on :4566
make smoke     # fast plumbing tests
make lambda    # optional: real Lambda execution (needs Docker)
make down      # stop + wipe
```

Without `make`, set the environment yourself:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566 AWS_DEFAULT_REGION=us-east-1 \
       AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
uv run --project ../.. --locked --only-group smoke-tests pytest -m smoke -q
```

If MiniStack is down locally, the suite skips cleanly. In environments without
Docker, including Cowork, run only non-Docker pytest suites.

## What This Does Not Prove

- IAM or STS tenant isolation. The emulator does not enforce real AWS trust and
  permission behavior.
- EKS, Karpenter, ARC, or runner orchestration. Those require a real environment.
- End-to-end Forge correctness. This suite is a liveness and wiring smoke check.
