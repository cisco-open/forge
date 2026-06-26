# Catalog Schemas

Catalog schemas make the skeleton enforceable. They prevent malformed
repository, image, schedule, and ownership config from reaching workflow logic.

## Validation Command Pattern

```bash
./scripts/validate-catalog.sh \
  --schema schemas/repositories.schema.json \
  --catalog config/repositories.yaml
```

The validator should exit nonzero when:

- required fields are missing
- unknown fields are present
- required checks are empty for a protected repository
- mutating automations lack an owner
- schedules lack manual dispatch support

## Repository Catalog Schema Example

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["metadata", "repositories"],
  "properties": {
    "metadata": {
      "type": "object",
      "required": ["default_branch", "default_visibility"],
      "properties": {
        "default_branch": { "type": "string" },
        "default_visibility": {
          "type": "string",
          "enum": ["private", "internal", "public"]
        },
        "template_repository": { "type": "string" }
      },
      "additionalProperties": false
    },
    "repositories": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "description", "teams", "branch_protection"],
        "properties": {
          "name": { "type": "string", "pattern": "^[a-z0-9][a-z0-9-]+$" },
          "description": { "type": "string", "minLength": 10 },
          "visibility": { "type": "string" },
          "template": { "type": "string" },
          "topics": { "type": "array", "items": { "type": "string" } },
          "teams": {
            "type": "object",
            "properties": {
              "readers": { "type": "array", "items": { "type": "string" } },
              "writers": { "type": "array", "items": { "type": "string" } },
              "maintainers": { "type": "array", "items": { "type": "string" } },
              "admins": { "type": "array", "items": { "type": "string" } }
            },
            "additionalProperties": false
          },
          "branch_protection": {
            "type": "object",
            "required": ["required_checks", "required_reviews"],
            "properties": {
              "required_checks": {
                "type": "array",
                "minItems": 1,
                "items": { "type": "string" }
              },
              "required_reviews": { "type": "integer", "minimum": 1 }
            },
            "additionalProperties": true
          },
          "rulesets": {
            "type": "object",
            "additionalProperties": true
          },
          "webhooks": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["name", "url", "events", "active", "secret_ref"],
              "properties": {
                "name": { "type": "string" },
                "url": { "type": "string" },
                "events": { "type": "array", "items": { "type": "string" } },
                "active": { "type": "boolean" },
                "secret_ref": { "type": "string" }
              },
              "additionalProperties": false
            }
          },
          "metadata": {
            "type": "object",
            "additionalProperties": { "type": "string" }
          }
        },
        "additionalProperties": false
      }
    }
  },
  "additionalProperties": false
}
```

## Automation Catalog Schema Example

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["automations"],
  "properties": {
    "automations": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "family", "owner", "source_of_truth", "final_check"],
        "properties": {
          "name": { "type": "string" },
          "family": {
            "type": "string",
            "enum": [
              "image-factory",
              "container-factory",
              "iac-operations",
              "repository-factory",
              "scheduled-job",
              "policy-hygiene",
              "dependency-automation",
              "migration"
            ]
          },
          "owner": { "type": "string" },
          "source_of_truth": { "type": "string" },
          "manual_dispatch": { "type": "boolean" },
          "schedule": { "type": ["string", "null"] },
          "final_check": { "type": "string" },
          "mutates_state": { "type": "boolean" },
          "approval_environment": { "type": ["string", "null"] }
        },
        "additionalProperties": false
      }
    }
  }
}
```

## Image Catalog Schema Example

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["images"],
  "properties": {
    "images": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["family", "path", "architectures", "smoke_test"],
        "properties": {
          "family": { "type": "string" },
          "path": { "type": "string" },
          "versions": { "type": "array", "items": { "type": "string" } },
          "architectures": { "type": "array", "items": { "type": "string" } },
          "smoke_test": { "type": "string" },
          "downstream_consumers": {
            "type": "array",
            "items": { "type": "string" }
          }
        },
        "additionalProperties": false
      }
    }
  }
}
```
