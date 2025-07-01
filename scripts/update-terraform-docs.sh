#!/bin/bash

# terraform-docs

# renovate: datasource=github-releases depName=terraform-docs/terraform-docs registryUrl=https://github.com/
TERRAFORM_DOCS_VERSION="0.20.0"
curl -sqLo /tmp/terraform-docs.tar.gz "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz"
tar -zxvf /tmp/terraform-docs.tar.gz -C /usr/local/bin/
chmod +x /usr/local/bin/terraform-docs

# renovate: datasource=github-releases depName=opentofu/opentofu registryUrl=https://github.com/
OPENTOFU_VERSION="1.9.1"
curl -sqLo /tmp/opentofu.tar.gz "https://github.com/opentofu/opentofu/releases/download/v${OPENTOFU_VERSION}/tofu_${OPENTOFU_VERSION}_linux_amd64.zip"
unzip -o /tmp/opentofu.tar.gz -d /usr/local/bin/
chmod +x /usr/local/bin/tofu

find modules/* -type d -not -path '*/\.*' -print0 | xargs -0 -I {} tofu -chdir={} init -backend=false
find modules/* -type f -name "*.tf" \
    -not -path '*/.*' \
    -not -path 'modules/integrations/splunk_cloud_data_manager/*' \
    -not -path 'modules/infra/forge_subscription/*' \
    -not -path 'modules/integrations/splunk_secrets/*' \
    -not -path 'modules/integrations/eks_secrets/*' \
    -exec dirname {} \; | sort -u | xargs -I {} terraform-docs -c .terraform-docs.yml {}
