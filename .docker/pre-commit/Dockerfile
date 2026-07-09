FROM ubuntu:26.04@sha256:b7f48194d4d8b763a478a621cdc81c27be222ba2206ca3ca6bc42b49685f3d9e AS build

WORKDIR /opt/build

# hadolint ignore=DL3008,DL3015
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    xz-utils

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# renovate: datasource=github-releases depName=gitleaks/gitleaks registryUrl=https://github.com/
ARG GITLEAKS_VERSION="8.30.1"
ARG GITLEAKS_SRC="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
ARG GITLEAKS_ARTIFACT="gitleaks.tar.gz"
RUN set -eux; \
    wget --progress=dot:giga -O ${GITLEAKS_ARTIFACT} ${GITLEAKS_SRC}; \
    tar -zxvf ${GITLEAKS_ARTIFACT} -C /usr/local/bin/; \
    chmod 755 /usr/local/bin/gitleaks

# renovate: datasource=github-releases depName=hadolint/hadolint registryUrl=https://github.com/
ARG HADOLINT_VERSION="2.14.0"
ARG HADOLINT_SRC="https://github.com/hadolint/hadolint/releases/download/v${HADOLINT_VERSION}/hadolint-Linux-x86_64"
ARG HADOLINT_ARTIFACT="hadolint"
RUN set -eux; \
    wget --progress=dot:giga -O ${HADOLINT_ARTIFACT} ${HADOLINT_SRC}; \
    mv ${HADOLINT_ARTIFACT} /usr/local/bin; \
    chmod 755 /usr/local/bin/hadolint

# Download jq.
# renovate: datasource=github-releases depName=jqlang/jq registryUrl=https://github.com/ extractVersion=^jq-(?<version>.*)$
ARG JQ_VERSION="1.8.2"
ARG JQ_SRC="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux64"
ARG JQ_ARTIFACT="jq"
RUN set -eux; \
    wget --progress=dot:giga -O ${JQ_ARTIFACT} ${JQ_SRC}; \
    mv ${JQ_ARTIFACT} /usr/local/bin/; \
    chmod 755 /usr/local/bin/jq

# renovate: datasource=github-releases depName=hashicorp/packer registryUrl=https://github.com/
ARG PACKER_VERSION="1.15.4"
ARG PACKER_SRC="https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip"
ARG PACKER_ARTIFACT="packer.zip"
RUN set -eux; \
    wget --progress=dot:giga -O ${PACKER_ARTIFACT} ${PACKER_SRC}; \
    unzip -o ${PACKER_ARTIFACT} -d /usr/local/bin/; \
    chmod 755 /usr/local/bin/packer; \
    rm ${PACKER_ARTIFACT}

# renovate: datasource=github-releases depName=koalaman/shellcheck registryUrl=https://github.com/
ARG SHELLCHECK_VERSION="0.11.0"
ARG SHELLCHECK_SRC="https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz"
ARG SHELLCHECK_ARTIFACT="shellcheck.tar.xz"
RUN set -eux; \
    wget --progress=dot:giga -O ${SHELLCHECK_ARTIFACT} ${SHELLCHECK_SRC}; \
    tar -xJvf ${SHELLCHECK_ARTIFACT}; \
    mv shellcheck-v${SHELLCHECK_VERSION}/shellcheck /usr/local/bin/shellcheck; \
    chmod 755 /usr/local/bin/shellcheck

# renovate: datasource=github-releases depName=mvdan/sh registryUrl=https://github.com/
ARG SHFMT_VERSION="3.13.1"
ARG SHFMT_SRC="https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64"
ARG SHFMT_ARTIFACT="shfmt"
RUN set -eux; \
    wget --progress=dot:giga -O ${SHFMT_ARTIFACT} ${SHFMT_SRC}; \
    mv ${SHFMT_ARTIFACT} /usr/local/bin; \
    chmod 755 /usr/local/bin/shfmt

# renovate: datasource=github-releases depName=terraform-docs/terraform-docs registryUrl=https://github.com/
ARG TERRAFORM_DOCS_VERSION="0.24.0"
ARG TERRAFORM_DOCS_SRC="https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz"
ARG TERRAFORM_DOCS_ARTIFACT="terraform-docs.tar.gz"
RUN set -eux; \
    wget --progress=dot:giga -O ${TERRAFORM_DOCS_ARTIFACT} ${TERRAFORM_DOCS_SRC}; \
    tar -zxvf ${TERRAFORM_DOCS_ARTIFACT} -C /usr/local/bin/;\
    chmod 755 /usr/local/bin/terraform-docs

# renovate: datasource=github-releases depName=gruntwork-io/terragrunt registryUrl=https://github.com/
ARG TERRAGRUNT_VERSION="1.1.0"
ARG TERRAGRUNT_SRC="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
ARG TERRAGRUNT_ARTIFACT="terragrunt"
RUN set -eux; \
    wget --progress=dot:giga -O ${TERRAGRUNT_ARTIFACT} ${TERRAGRUNT_SRC}; \
    mv ${TERRAGRUNT_ARTIFACT} /usr/local/bin; \
    chmod 755 /usr/local/bin/terragrunt

# renovate: datasource=github-releases depName=terraform-linters/tflint registryUrl=https://github.com/
ARG TFLINT_VERSION="0.63.1"
ARG TFLINT_SRC="https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip"
ARG TFLINT_ARTIFACT="tflint.zip"
RUN set -eux; \
    wget --progress=dot:giga -O ${TFLINT_ARTIFACT} ${TFLINT_SRC}; \
    unzip -o ${TFLINT_ARTIFACT} -d /usr/local/bin/; \
    chmod 755 /usr/local/bin/tflint;

# renovate: datasource=github-releases depName=opentofu/opentofu registryUrl=https://github.com/
ARG TOFU_VERSION="1.12.3"
ARG TOFU_SRC="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip"
ARG TOFU_ARTIFACT="tofu.zip"
RUN set -eux; \
    wget --progress=dot:giga -O ${TOFU_ARTIFACT} ${TOFU_SRC}; \
    unzip -o ${TOFU_ARTIFACT} -d /usr/local/bin/; \
    chmod 755 /usr/local/bin/tofu

FROM ubuntu:26.04@sha256:b7f48194d4d8b763a478a621cdc81c27be222ba2206ca3ca6bc42b49685f3d9e AS final

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /opt/build

# hadolint ignore=DL3008,DL3015
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    git \
    python3.12 \
    python3.12-venv \
    python3-pip \
    ruby3.2 \
    build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy tools from build stage
COPY --from=build /usr/local/bin/gitleaks /usr/local/bin/gitleaks
COPY --from=build /usr/local/bin/hadolint /usr/local/bin/hadolint
COPY --from=build /usr/local/bin/jq /usr/local/bin/jq
COPY --from=build /usr/local/bin/packer /usr/local/bin/packer
COPY --from=build /usr/local/bin/shfmt /usr/local/bin/shfmt
COPY --from=build /usr/local/bin/shellcheck /usr/local/bin/shellcheck
COPY --from=build /usr/local/bin/terraform-docs /usr/local/bin/terraform-docs
COPY --from=build /usr/local/bin/terragrunt /usr/local/bin/terragrunt
COPY --from=build /usr/local/bin/tflint /usr/local/bin/tflint
COPY --from=build /usr/local/bin/tofu /usr/local/bin/tofu

COPY pyproject.toml uv.lock ./

# hadolint ignore=DL3013
RUN set -eux; \
    uv_version="$(python3.12 -c 'import tomllib; data = tomllib.load(open("pyproject.toml", "rb")); print(next(dep.removeprefix("uv==") for dep in data["dependency-groups"]["pre-commit-image"] if dep.startswith("uv==")))')"; \
    pip install --no-cache-dir --break-system-packages "uv==${uv_version}"; \
    uv export --locked --only-group pre-commit-image --format requirements-txt --no-hashes > /tmp/pre-commit-image-requirements.txt; \
    pip install --no-cache-dir --break-system-packages --ignore-installed -r /tmp/pre-commit-image-requirements.txt; \
    rm /tmp/pre-commit-image-requirements.txt
