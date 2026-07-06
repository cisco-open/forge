# Draft Mermaid Diagram Conversions

This folder contains draft Mermaid conversions for the image diagrams in
`docs/img`. These are intentionally separate from the current README image
references so they can be reviewed before replacing the JPEGs.

## Source Images

| Source image                     | Draft                                            | Mermaid-rendered preview                                             |
| -------------------------------- | ------------------------------------------------ | -------------------------------------------------------------------- |
| `../img/10k_ft.jpg`              | [10k_ft.md](10k_ft.md)                           | [rendered/10k_ft.png](rendered/10k_ft.png)                           |
| `../img/10k_ft_multi_tenant.jpg` | [10k_ft_multi_tenant.md](10k_ft_multi_tenant.md) | [rendered/10k_ft_multi_tenant.png](rendered/10k_ft_multi_tenant.png) |
| `../img/10k_ft_tenant.jpg`       | [10k_ft_tenant.md](10k_ft_tenant.md)             | [rendered/10k_ft_tenant.png](rendered/10k_ft_tenant.png)             |
| `../img/forge_runner_ec2.jpg`    | [forge_runner_ec2.md](forge_runner_ec2.md)       | [rendered/forge_runner_ec2.png](rendered/forge_runner_ec2.png)       |
| `../img/forge_runner_eks.jpg`    | [forge_runner_eks.md](forge_runner_eks.md)       | [rendered/forge_runner_eks.png](rendered/forge_runner_eks.png)       |
| `../img/forge_architecture.jpg`  | [forge_architecture.md](forge_architecture.md)   | [rendered/forge_architecture.png](rendered/forge_architecture.png)   |

## PNG Render Workflow

The Mermaid drafts use a local Iconify icon pack named `aws-forge` so the
rendered PNGs can keep the AWS/Miro-style symbols from the source images.
GitHub Markdown does not load this custom icon pack directly, so the PNG files
in `rendered/` are the review and replacement artifacts when exact icons are
required.

The icon pack is checked in at
[`icon-packs/aws-forge-icons.json`](icon-packs/aws-forge-icons.json). It uses
official AWS Architecture Icons for AWS services and embedded transparent PNG
crops from the source Miro exports for Forge-specific symbols that do not exist
as AWS icons.

Install Mermaid CLI outside the repository, then render all previews:

```bash
npm install --prefix /private/tmp/forge-mermaid-render @mermaid-js/mermaid-cli
MMDC=/private/tmp/forge-mermaid-render/node_modules/.bin/mmdc docs/diagram-drafts/render_pngs.sh
```

The script starts a local-only CORS server for the icon pack, renders each
Mermaid Markdown file with a white background, and normalizes Mermaid CLI's
Markdown output filenames back to `rendered/<diagram>.png`.

## Reusable Conversion Prompt

Use this prompt when converting another Forge diagram image into Mermaid:

```text
You are converting a ForgeMT AWS architecture diagram from a PNG/JPG exported
from Miro into Mermaid Markdown.

Goal:
- Preserve the same diagram boards, containers, ownership overlays, labels,
  and arrows as closely as Mermaid supports.
- Create a Mermaid diagram and a short textual description of what the diagram
  shows.
- Do not invent architecture. Use only information visible in the image or
  documented in this repository.

Repository evidence to check before enhancing anything:
- README.md for platform summary and existing image captions.
- docs/reference/module-layout.md for module ownership and boundaries.
- docs/getting-started/configure-platform.md for the normal Forge runner entry
  point.
- modules/platform/forge_runners/README.md for tenant runner stack behavior.
- modules/platform/ec2_deployment/README.md for EC2 runner behavior.
- modules/platform/arc/README.md and modules/platform/arc/scale_set/README.md
  for ARC/EKS runner behavior.
- modules/infra/eks/README.md for the EKS foundation.
- modules/helpers/forge_subscription/README.md for tenant IAM/ECR bridge
  behavior.

Output format:
1. Source image path.
2. Textual description.
3. Mermaid code block.
4. Evidence used, with repo paths.
5. Review notes for unclear labels, ambiguous arrow direction, or anything
   Mermaid cannot represent exactly.

Rules:
- Keep source image labels unless the repo documentation clearly uses a more
  precise name.
- Prefer Mermaid `architecture-beta` only when it keeps the source image layout
  readable. Use `group`, `service`, side-directed edges, and `align row` /
  `align column` when constraints are enough.
- If `architecture-beta` creates sparse, crossed, or unreadable diagrams, use
  Mermaid `block` with fixed rows/columns and image labels. Block diagrams keep
  Miro-like board organization better, but they do not support normal edge
  labels, so keep detailed relationship text in the description and notes.
- Use `aws-forge:<icon-name>` icon references in `architecture-beta` diagrams.
  Use `http://127.0.0.1:8123/assets/<icon>.svg` image labels in block diagrams;
  the render script serves those assets locally.
- Force a white diagram background so GitHub dark mode does not place dark text
  and arrows on a dark transparent canvas.
- If an arrow crosses boundaries in the image but the source/target is unclear,
  model the visible direction only and add a review note.
- If you use repository knowledge to clarify a label, cite the file that
  documents it.
- Mark any uncertain item as "Needs review" instead of guessing.
```

## Conversion Notes

- Mermaid cannot fully reproduce Miro's transparent overlapping boards or
  per-board fill colors. These drafts use a mix of `architecture-beta` and
  `block` diagrams, custom icons, theme variables, rendered PNG previews, and
  renderer-side CSS to preserve architecture boundaries and data/control flows.
- Mermaid `architecture-beta` supports only a small built-in icon set by
  default. The PNG workflow registers the checked-in `aws-forge` Iconify pack
  at render time. Block diagrams use extracted SVG assets from the same pack.
  Raw GitHub Mermaid may show placeholders or missing local assets for those
  icons.
- `architecture-beta` only exposes one Mermaid theme variable for group border
  color. Architecture-beta previews use
  [`architecture-group-colors.css`](architecture-group-colors.css) with Mermaid
  CLI's `--cssFile` / `-C` option to color each group boundary separately.
- Dense diagrams such as `forge_architecture.md` may need larger rendered
  previews than the default Mermaid CLI width because the architecture layout
  spreads many labeled edges over a larger canvas.
- The source images use both `Github` and `GitHub`. Diagram labels generally
  keep the spelling visible in the source images. Descriptions use `GitHub`.
- The full architecture image uses `Tenant SL AWS Account`, while smaller
  diagrams use `Tenant AWS Account`. The draft keeps the full image label and
  flags it for review.
- `rendered/` contains PNG previews generated from the Mermaid drafts. Use
  these PNGs in GitHub-rendered docs when exact custom icons matter; the
  Mermaid Markdown remains the editable source of truth.

## Custom Icon Pack

Use the `aws-forge:` icon namespace in architecture-beta Mermaid source. Block
diagrams use SVG image assets in `icon-packs/assets/`. Render both styles with
`render_pngs.sh`.

| Icon family                                                                                          | Source                                                 |
| ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| AWS account, region, cloud, ECR, EKS, AMI, Lambda, API Gateway, CloudWatch, EC2 instances            | Official AWS Architecture Icons package                |
| Forge control plane, pod runner, GitHub App, runner group, tenant IAM role, AWS services, ECR policy | Cropped from the source Miro-exported PNG/JPG diagrams |

## Visual Palette

Use the same palette across all Mermaid replacements so the diagrams read as a
single documentation set.

| Element                           | Background | Border / Arrow   | Text      |
| --------------------------------- | ---------- | ---------------- | --------- |
| Page / diagram                    | `#ffffff`  | n/a              | `#111827` |
| AWS Cloud board                   | `#ffffff`  | `#334155` dashed | `#111827` |
| Forge account                     | `#fff7fb`  | `#be185d`        | `#111827` |
| Tenant AWS account                | `#fff7fb`  | `#be185d`        | `#111827` |
| Region                            | `#f0fdf4`  | `#047857`        | `#111827` |
| Forge instance overlay            | `#f0f7ff`  | `#0284c7` dashed | `#111827` |
| Relationship label lane           | `#f8fafc`  | `#cbd5e1` dashed | `#111827` |
| GitHub board                      | `#faf5ff`  | `#7e22ce` dashed | `#111827` |
| Managed by tenant overlay         | `#fee2e2`  | `#dc2626` dashed | `#111827` |
| Managed by GH admin overlay       | `#ffedd5`  | `#ea580c` dashed | `#111827` |
| Runner group overlay              | `#fce7f3`  | `#be185d` dashed | `#111827` |
| Splunk / observability            | `#fffbeb`  | `#ca8a04` dashed | `#111827` |
| Internal network                  | `#eef2ff`  | `#4338ca` dashed | `#111827` |
| AWS resources / ECR / AMI / nodes | `#fff7ed`  | `#ea580c`        | `#111827` |
| IAM / roles / policy              | `#fff1f2`  | `#be123c`        | `#111827` |
| Pods / Kubernetes                 | `#eff6ff`  | `#2563eb`        | `#111827` |
| GitHub repo / app / user          | `#ffffff`  | `#334155`        | `#111827` |
| Logs / CloudWatch                 | `#fdf2f8`  | `#be185d`        | `#111827` |
| Lambda / jobs                     | `#fffbeb`  | `#d97706`        | `#111827` |

Rendered group-border overrides:

| Group / board             | Border    |
| ------------------------- | --------- |
| AWS Cloud                 | `#334155` |
| Forge account             | `#db2777` |
| Region                    | `#059669` |
| Forge instance            | `#0284c7` |
| Tenant AWS account        | `#e11d48` |
| GitHub                    | `#7e22ce` |
| Managed by tenant         | `#dc2626` |
| Managed by GH admin       | `#ea580c` |
| Forge GitHub runner group | `#be185d` |
| Managed by Forge Team     | `#0f766e` |
| Splunk / observability    | `#ca8a04` |
| Internal network          | `#4338ca` |

Arrow colors:

| Arrow type       | Color     |
| ---------------- | --------- |
| Default          | `#1f2937` |
| IAM / trust      | `#be123c` |
| Runtime / runner | `#2563eb` |
| GitHub flow      | `#7e22ce` |
| Observability    | `#ca8a04` |
| Internal network | `#4338ca` |
