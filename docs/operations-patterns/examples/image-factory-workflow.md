# Example: Image Factory Workflow

Use this shape for a runner base-image repository. It mirrors the important
operational pattern: compute version, decide the matrix, bake images, test the
candidate image, optionally build a downstream image, and expose one stable
validation job.

```yaml
name: Runner Image Factory

on:
  pull_request:
    paths:
      - "images/**"
      - "ansible/**"
      - ".github/workflows/image-factory.yml"
  push:
    branches: [main]
    paths:
      - "images/**"
      - "ansible/**"
      - ".github/workflows/image-factory.yml"
  workflow_dispatch:
    inputs:
      image_family:
        description: "Image family to build, or all"
        type: choice
        options: [all, linux, macos, windows]
        default: all
      publish:
        description: "Publish image after tests"
        type: boolean
        default: false

permissions:
  contents: read
  pull-requests: write

concurrency:
  group: image-factory-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: false

jobs:
  compute-version:
    runs-on: <runner-label>
    outputs:
      version: ${{ steps.version.outputs.version }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - id: version
        shell: bash
        run: |
          version="$(date -u +%Y%m%d)-${GITHUB_SHA::8}"
          echo "version=${version}" >> "$GITHUB_OUTPUT"

  determine-matrix:
    runs-on: <runner-label>
    outputs:
      image_matrix: ${{ steps.matrix.outputs.image_matrix }}
      has_images: ${{ steps.matrix.outputs.has_images }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - id: matrix
        shell: bash
        run: |
          # Replace with repository-specific discovery.
          cat > image-matrix.json <<'JSON'
          [
            {"family":"linux","version":"24.04","arch":"amd64","path":"images/linux/24.04"},
            {"family":"linux","version":"24.04","arch":"arm64","path":"images/linux/24.04"},
            {"family":"windows","version":"2025","arch":"amd64","path":"images/windows/2025"}
          ]
          JSON
          echo "image_matrix=$(jq -c . image-matrix.json)" >> "$GITHUB_OUTPUT"
          echo "has_images=true" >> "$GITHUB_OUTPUT"

  bake-image:
    needs: [compute-version, determine-matrix]
    if: needs.determine-matrix.outputs.has_images == 'true'
    runs-on: <runner-label>
    strategy:
      fail-fast: false
      matrix:
        image: ${{ fromJSON(needs.determine-matrix.outputs.image_matrix) }}
    outputs:
      # In real workflows, collect candidate identifiers in a follow-up job.
      built: "true"
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - name: Bake image
        shell: bash
        env:
          IMAGE_PATH: ${{ matrix.image.path }}
          IMAGE_VERSION: ${{ needs.compute-version.outputs.version }}
        run: |
          ./scripts/bake-image.sh "$IMAGE_PATH" "$IMAGE_VERSION"

  collect-test-matrix:
    needs: [determine-matrix, bake-image]
    if: always() && needs.bake-image.result == 'success'
    runs-on: <runner-label>
    outputs:
      test_matrix: ${{ steps.collect.outputs.test_matrix }}
    steps:
      - id: collect
        shell: bash
        run: |
          # Replace with the image identifiers emitted by bake-image.
          cat > test-matrix.json <<'JSON'
          [
            {"image_id":"<candidate-image-id>","family":"linux","arch":"amd64"}
          ]
          JSON
          echo "test_matrix=$(jq -c . test-matrix.json)" >> "$GITHUB_OUTPUT"

  test-image:
    needs: [collect-test-matrix]
    runs-on: <runner-label>
    strategy:
      fail-fast: false
      matrix:
        candidate: ${{ fromJSON(needs.collect-test-matrix.outputs.test_matrix) }}
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - name: Run smoke test
        shell: bash
        run: |
          ./scripts/test-runner-image.sh "${{ matrix.candidate.image_id }}"

  publish-image:
    needs: [test-image]
    if: github.event_name != 'pull_request' && inputs.publish == true
    runs-on: <runner-label>
    environment: image-publish
    steps:
      - uses: actions/checkout@<pinned-version>
      - uses: ./.github/actions/<auth-adapter>
      - name: Publish candidate
        shell: bash
        run: ./scripts/publish-image.sh

  validate:
    needs: [determine-matrix, bake-image, collect-test-matrix, test-image]
    if: always()
    runs-on: <runner-label>
    steps:
      - name: Validate required jobs
        shell: bash
        run: |
          test "${{ needs.determine-matrix.result }}" = "success"
          test "${{ needs.bake-image.result }}" = "success"
          test "${{ needs.collect-test-matrix.result }}" = "success"
          test "${{ needs.test-image.result }}" = "success"
```

## Replace Before Use

- `./scripts/bake-image.sh`
- `./scripts/test-runner-image.sh`
- `./scripts/publish-image.sh`
- `<auth-adapter>`
- `<runner-label>`
- image discovery logic
- candidate image identifier collection
