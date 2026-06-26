# Example: Container Factory Workflow

Use this for helper containers that Forge automation depends on, such as runner
containers, quality-tool containers, or maintenance containers.

```yaml
name: Container Factory

on:
  pull_request:
    paths:
      - "containers/<container-name>/**"
      - ".github/workflows/container-factory.yml"
  push:
    branches: [main]
    paths:
      - "containers/<container-name>/**"
      - ".github/workflows/container-factory.yml"
  workflow_dispatch:
    inputs:
      publish:
        type: boolean
        default: false

permissions:
  contents: read

jobs:
  build:
    runs-on: <runner-label>
    outputs:
      image_ref: ${{ steps.meta.outputs.image_ref }}
      image_digest: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<registry-adapter>
      - id: meta
        shell: bash
        run: |
          image_ref="<registry>/<namespace>/<container-name>:${GITHUB_SHA::12}"
          echo "image_ref=${image_ref}" >> "$GITHUB_OUTPUT"
      - id: build
        shell: bash
        run: |
          docker build \
            --file containers/<container-name>/Dockerfile \
            --tag "${{ steps.meta.outputs.image_ref }}" \
            containers/<container-name>
          digest="$(docker image inspect "${{ steps.meta.outputs.image_ref }}" --format '{{index .RepoDigests 0}}' || true)"
          echo "digest=${digest}" >> "$GITHUB_OUTPUT"

  check-image:
    needs: build
    runs-on: <runner-label>
    steps:
      - name: Smoke check produced image
        shell: bash
        run: |
          docker run --rm "${{ needs.build.outputs.image_ref }}" --version

  publish:
    needs: [build, check-image]
    if: github.event_name == 'workflow_dispatch' && inputs.publish == true
    runs-on: <runner-label>
    environment: container-publish
    steps:
      - uses: ./.github/actions/<registry-adapter>
      - name: Push image
        shell: bash
        run: docker push "${{ needs.build.outputs.image_ref }}"

  validate:
    needs: [build, check-image]
    if: always()
    runs-on: <runner-label>
    steps:
      - shell: bash
        run: |
          test "${{ needs.build.result }}" = "success"
          test "${{ needs.check-image.result }}" = "success"
```

## Replace Before Use

- `<registry>`
- `<namespace>`
- `<container-name>`
- `<registry-adapter>`
- smoke command
- publish environment
