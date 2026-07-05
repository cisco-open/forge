# Global Lock Action

This action ensures that only one job runs at a time by using a DynamoDB-based locking mechanism. It is useful for workflows that require global synchronization across multiple jobs or workflows.

## Inputs

- `lock-id`: **(required)** A unique identifier for the lock. This is used to identify the lock in the DynamoDB table.
- `lock-action`: **(required)** The action to perform on the lock. Valid values are:
  - `acquire`: Acquire the lock.
  - `release`: Release the lock.
- `lock-ttl`: **(optional)** The time-to-live (TTL) for the lock in seconds. Defaults to `172800` (48 hours).

## How It Works

1. The action retrieves the AWS role prefix and region from the environment.
1. It defines lock variables, including the workflow run ID, expiration timestamp (TTL), and the DynamoDB table name.
1. Depending on the `lock-action` input:
   - If `acquire`, the action attempts to acquire the lock by checking if it already exists in the DynamoDB table.
     - If the lock exists, it waits and retries until the lock is released.
     - If the lock does not exist, it creates the lock in the DynamoDB table.
   - If `release`, the action releases the lock by removing it from the DynamoDB table.

## Example Usage

### Acquiring a Lock

```yaml
jobs:
  acquire-lock:
    runs-on: ubuntu-latest
    steps:
      - name: Acquire Global Lock
        uses: ./.github/actions/global-lock-action
        with:
          lock-id: 'my-unique-lock-id'
          lock-action: 'acquire'
          lock-ttl: '3600' # Optional, 1 hour
```

### Releasing a Lock

```yaml
jobs:
  release-lock:
    runs-on: ubuntu-latest
    steps:
      - name: Release Global Lock
        uses: ./.github/actions/global-lock-action
        with:
          lock-id: 'my-unique-lock-id'
          lock-action: 'release'
```
