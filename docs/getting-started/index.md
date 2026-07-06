# Getting Started

Use this section when you are installing ForgeMT as a self-hosted GitHub
Actions runner platform in a new AWS estate or turning the examples into your
own operations repos.

Follow the pages in order:

| Step | Page                                                | What you should have after it                                          |
| ---- | --------------------------------------------------- | ---------------------------------------------------------------------- |
| 1    | [Prerequisites](prerequisites.md)                   | AWS, GitHub, state, tools, and secrets decisions.                      |
| 2    | [Bootstrap](bootstrap.md)                           | AWS profile, remote state, GitHub App, SSM key flow, and runner image. |
| 3    | [Minimal Install](minimal-install.md)               | One working GitHub.com org-level tenant runner lane.                   |
| 4    | [Repository Layout](repository-layout.md)           | Clear split between Forge source, examples, and your operating repos.  |
| 5    | [Deployment Order](deployment-order.md)             | The exact order for helpers, infra, platform, and integrations.        |
| 6    | [Configure Helpers](configure-helpers.md)           | Optional account preparation and operations helpers.                   |
| 7    | [Configure Infra](configure-infra.md)               | EKS foundation if you plan to run ARC scale sets.                      |
| 8    | [Configure Platform](configure-platform.md)         | One working tenant runner deployment.                                  |
| 9    | [First Tenant](first-tenant.md)                     | A copy/change/run tenant onboarding path.                              |
| 10   | [Configure Integrations](configure-integrations.md) | Optional Splunk, Teleport, OTel, OpenCost, and webhook relay pieces.   |

For a small first deployment, use GitHub.com with one organization, one tenant,
and one runner lane. Pick EC2 when you already have a runner AMI and want the
smallest AWS footprint. Pick ARC when EKS is already part of the first
deployment. Add Splunk, Teleport, and webhook relay destination modules only
after the platform path works.
