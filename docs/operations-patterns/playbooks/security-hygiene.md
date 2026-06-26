# Playbook: Security Hygiene

## Goal

Prevent secrets, credentials, private endpoints, and sensitive operational
details from entering docs, examples, logs, or commits.

## Use When

- Editing configuration.
- Adding examples.
- Copying log samples.
- Writing incident or PR notes.

## Inputs

- Changed files.
- Any copied logs, payloads, screenshots, or config samples.

## Checklist

1. Search the diff for tokens, keys, private endpoints, and internal identifiers.
1. Keep secret retrieval in local adapters instead of generic playbooks.
1. Replace real identities with placeholders in examples.
1. Run the repo-local secret scan.
1. Review PR text for copied sensitive values.
1. Document any redaction assumptions.

## Definition Of Done

- No sensitive values appear in committed files or PR text.
- Security hooks pass or a false positive is documented.
- Examples remain useful with placeholders.

## Common Failures

- Copying real workflow logs into documentation.
- Leaving internal identifiers in shareable templates.
- Disabling a scan instead of fixing the finding.
