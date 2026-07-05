# Compute Terragrunt Layers Action

Compute Terragrunt execution layers from a Terragrunt DAG and expose them as JSON for downstream matrix usage.

## Inputs

- `tf-path` (required): Path to the root of your Terragrunt configuration (the folder where you would run Terragrunt commands). The action will execute `terragrunt dag graph` from this path.

## Outputs

- `layers-json`: A JSON-encoded array of layers, where each layer contains the modules to run at that stage of the DAG. Example shape:

```
[
  [
    { "name": "bootstrap", "path": "terraform/environments/dev/bootstrap" }
  ],
  [
    { "name": "network", "path": "terraform/environments/dev/network" },
    { "name": "teleport", "path": "terraform/environments/dev/teleport" }
  ]
]
```

## Requirements

- Terragrunt must be available on PATH in the runner.
- Python 3 must be available to run the compute_layers.py script.

## Example Usage

```yaml
jobs:
  discover:
    runs-on: ubuntu-latest
    outputs:
      layers: ${{ steps.compute.outputs.layers-json }}
    steps:
      - uses: actions/checkout@v5

      - name: Compute Terragrunt layers
        id: compute
        uses: your-org/forge-reusable-actions/.github/actions/compute-terragrunt-layers-action@<commit-sha>
        with:
          tf-path: terraform/environments/dev

  deploy:
    needs: discover
    strategy:
      fail-fast: false
      matrix:
        layer: ${{ fromJSON(needs.discover.outputs.layers) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5
      - name: Run Terragrunt for layer
        run: |
          echo "Running layer: ${{ toJson(matrix.layer) }}"
          # Iterate over modules in the layer and run terragrunt
```

## Notes

- The output format depends on `scripts/compute_layers.py`. Adjust downstream consumers accordingly if you change that script.
- If you need separate matrices (e.g., tenants vs teleport), split `layers-json` accordingly in a preparatory step.
