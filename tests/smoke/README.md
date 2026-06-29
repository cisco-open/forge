# Forge smoke tests (MiniStack)

Shallow "is the plumbing alive" checks against a local MiniStack emulator.
No AWS account, no auth token, no Forge code required.

## Run locally

```bash
pip install -r requirements-dev.txt
make up        # start MiniStack on :4566
make smoke     # fast plumbing tests
make lambda    # optional: real Lambda execution (needs Docker)
make down      # stop + wipe
```

Without `make`, set the env yourself:

```bash
export AWS_ENDPOINT_URL=http://localhost:4566 AWS_DEFAULT_REGION=us-east-1 \
       AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
pytest -m smoke -q
```

## What's covered

S3 (tenant log bucket), SQS + DLQ (event queue), SSM SecureString (webhook
secret), EventBridge, CloudWatch Logs, STS identity, IAM role create + assume.
Shaped after Forge's data plane.

## What these do NOT prove

- IAM/STS isolation: the emulator does not enforce trust/permission policies, so
  role assumption is a mechanics check, not an isolation guarantee.
- EKS / Karpenter / ARC / runner orchestration: not emulated meaningfully.
  Use real ephemeral AWS for those.

## Notes

- If MiniStack is down, the suite SKIPS locally but FAILS in CI
  (FORGE_REQUIRE_MINISTACK=1) so it can't pass green vacuously.
- Pin the MiniStack image to a real tag in docker-compose.yml for reproducibility.
