FROM ubuntu:24.04 AS build

WORKDIR /opt/build

# hadolint ignore=DL3008,DL3015
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    unzip \
    xz-utils

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# renovate: datasource=github-releases depName=gitleaks/gitleaks registryUrl=https://github.com/
ARG GITLEAKS_VERSION="8.24.3"
ARG GITLEAKS_SRC="https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz"
ARG GITLEAKS_ARTIFACT="gitleaks.tar.gz"
ARG GITLEAKS_CHECKSUM="9991e0b2903da4c8f6122b5c3186448b927a5da4deef1fe45271c3793f4ee29c"
RUN set -eux; \
    wget --progress=dot:giga -O ${GITLEAKS_ARTIFACT} ${GITLEAKS_SRC}; \
    echo "${GITLEAKS_CHECKSUM} ${GITLEAKS_ARTIFACT}" | sha256sum -c -; \
    tar -zxvf ${GITLEAKS_ARTIFACT} -C /usr/local/bin/; \
    chmod 755 /usr/local/bin/gitleaks

# renovate: datasource=github-releases depName=hadolint/hadolint registryUrl=https://github.com/
ARG HADOLINT_VERSION="v2.12.0"
ARG HADOLINT_SRC="https://github.com/hadolint/hadolint/releases/download/v2.12.0/hadolint-Linux-x86_64"
ARG HADOLINT_ARTIFACT="hadolint"
ARG HADOLINT_CHECKSUM="56de6d5e5ec427e17b74fa48d51271c7fc0d61244bf5c90e828aab8362d55010"
RUN set -eux; \
    wget --progress=dot:giga -O ${HADOLINT_ARTIFACT} ${HADOLINT_SRC}; \
    echo "${HADOLINT_CHECKSUM} ${HADOLINT_ARTIFACT}" | sha256sum -c -; \
    mv ${HADOLINT_ARTIFACT} /usr/local/bin; \
    chmod 755 /usr/local/bin/hadolint

# Download jq.
# renovate: datasource=github-releases depName=stedolan/jq registryUrl=https://github.com/
ARG JQ_VERSION="1.7.1"
ARG JQ_SRC="https://github.com/stedolan/jq/releases/download/jq-${JQ_VERSION}/jq-linux64"
ARG JQ_ARTIFACT="jq"
ARG JQ_CHECKSUM="5942c9b0934e510ee61eb3e30273f1b3fe2590df93933a93d7c58b81d19c8ff5"
RUN set -eux; \
    wget --progress=dot:giga -O ${JQ_ARTIFACT} ${JQ_SRC}; \
    echo "${JQ_CHECKSUM} ${JQ_ARTIFACT}" | sha256sum -c -; \
    mv ${JQ_ARTIFACT} /usr/local/bin/; \
    chmod 755 /usr/local/bin/jq

# renovate: datasource=github-releases depName=hashicorp/packer registryUrl=https://github.com/
ARG PACKER_VERSION="1.12.0"
ARG PACKER_SRC="https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip"
ARG PACKER_ARTIFACT="packer.zip"
ARG PACKER_CHECKSUM="e859a76659570d1e29fa55396d5d908091bacacd4567c17770e616c4b58c9ace"
RUN set -eux; \
    wget --progress=dot:giga -O ${PACKER_ARTIFACT} ${PACKER_SRC}; \
    echo "${PACKER_CHECKSUM} ${PACKER_ARTIFACT}" | sha256sum -c -; \
    unzip -o ${PACKER_ARTIFACT} -d /usr/local/bin/; \
    chmod 755 /usr/local/bin/packer; \
    rm ${PACKER_ARTIFACT}

# renovate: datasource=github-releases depName=koalaman/shellcheck registryUrl=https://github.com/
ARG SHELLCHECK_VERSION="0.10.0"
ARG SHELLCHECK_SRC="https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz"
ARG SHELLCHECK_ARTIFACT="shellcheck.tar.xz"
ARG SHELLCHECK_CHECKSUM="6c881ab0698e4e6ea235245f22832860544f17ba386442fe7e9d629f8cbedf87"
RUN set -eux; \
    wget --progress=dot:giga -O ${SHELLCHECK_ARTIFACT} ${SHELLCHECK_SRC}; \
    echo "${SHELLCHECK_CHECKSUM} ${SHELLCHECK_ARTIFACT}" | sha256sum -c -; \
    tar -xJvf ${SHELLCHECK_ARTIFACT}; \
    mv shellcheck-v${SHELLCHECK_VERSION}/shellcheck /usr/local/bin/shellcheck; \
    chmod 755 /usr/local/bin/shellcheck

# renovate: datasource=github-releases depName=mvdan/sh registryUrl=https://github.com/
ARG SHFMT_VERSION="3.11.0"
ARG SHFMT_SRC="https://github.com/mvdan/sh/releases/download/v${SHFMT_VERSION}/shfmt_v${SHFMT_VERSION}_linux_amd64"
ARG SHFMT_ARTIFACT="shfmt"
ARG SHFMT_CHECKSUM="1904ec6bac715c1d05cd7f6612eec8f67a625c3749cb327e5bfb4127d09035ff"
RUN set -eux; \
    wget --progress=dot:giga -O ${SHFMT_ARTIFACT} ${SHFMT_SRC}; \
    echo "${SHFMT_CHECKSUM} ${SHFMT_ARTIFACT}" | sha256sum -c -; \
    mv ${SHFMT_ARTIFACT} /usr/local/bin; \
    chmod 755 /usr/local/bin/shfmt

# renovate: datasource=github-releases depName=terraform-docs/terraform-docs registryUrl=https://github.com/
ARG TERRAFORM_DOCS_VERSION="0.20.0"
ARG TERRAFORM_DOCS_SRC="https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz"
ARG TERRAFORM_DOCS_ARTIFACT="terraform-docs.tar.gz"
ARG TERRAFORM_DOCS_CHECKSUM="34ae01772412bb11474e6718ea62113e38ff5964ee570a98c69fafe3a6dff286"
RUN set -eux; \
    wget --progress=dot:giga -O ${TERRAFORM_DOCS_ARTIFACT} ${TERRAFORM_DOCS_SRC}; \
    echo "${TERRAFORM_DOCS_CHECKSUM} ${TERRAFORM_DOCS_ARTIFACT}" | sha256sum -c -; \
    tar -zxvf ${TERRAFORM_DOCS_ARTIFACT} -C /usr/local/bin/;\
    chmod 755 /usr/local/bin/terraform-docs

# renovate: datasource=github-releases depName=gruntwork-io/terragrunt registryUrl=https://github.com/
ARG TERRAGRUNT_VERSION="0.77.22"
ARG TERRAGRUNT_SRC="https://github.com/gruntwork-io/terragrunt/releases/download/v${TERRAGRUNT_VERSION}/terragrunt_linux_amd64"
ARG TERRAGRUNT_ARTIFACT="terragrunt"
ARG TERRAGRUNT_CHECKSUM="42036586250f5db53dd2460427c5df43420fa22b935998f1530181474f525386"
RUN set -eux; \
    wget --progress=dot:giga -O ${TERRAGRUNT_ARTIFACT} ${TERRAGRUNT_SRC}; \
    echo "${TERRAGRUNT_CHECKSUM} ${TERRAGRUNT_ARTIFACT}" | sha256sum -c -; \
    mv ${TERRAGRUNT_ARTIFACT} /usr/local/bin; \
    chmod 755 /usr/local/bin/terragrunt

# renovate: datasource=github-releases depName=terraform-linters/tflint registryUrl=https://github.com/
ARG TFLINT_VERSION="0.56.0"
ARG TFLINT_SRC="https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip"
ARG TFLINT_ARTIFACT="tflint.zip"
ARG TFLINT_CHECKSUM="e0d74c557815ee51c6ecfe826ed62fd411ee6c10e1eab5532a0b0cc684c5db8a"
RUN set -eux; \
    wget --progress=dot:giga -O ${TFLINT_ARTIFACT} ${TFLINT_SRC}; \
    echo "${TFLINT_CHECKSUM} ${TFLINT_ARTIFACT}" | sha256sum -c -; \
    unzip -o ${TFLINT_ARTIFACT} -d /usr/local/bin/; \
    chmod 755 /usr/local/bin/tflint

# renovate: datasource=github-releases depName=opentofu/opentofu registryUrl=https://github.com/
ARG TOFU_VERSION="1.9.1"
ARG TOFU_SRC="https://github.com/opentofu/opentofu/releases/download/v${TOFU_VERSION}/tofu_${TOFU_VERSION}_linux_amd64.zip"
ARG TOFU_ARTIFACT="tofu.zip"
ARG TOFU_CHECKSUM="19eda43eaa45bef3e21d87c58f31a6df73e8534ea30e78619a463bdfdb889cd2"
RUN set -eux; \
    wget --progress=dot:giga -O ${TOFU_ARTIFACT} ${TOFU_SRC}; \
    echo "${TOFU_CHECKSUM} ${TOFU_ARTIFACT}" | sha256sum -c -; \
    unzip -o ${TOFU_ARTIFACT} -d /usr/local/bin/; \
    chmod 755 /usr/local/bin/tofu

FROM ubuntu:24.04 AS final

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /opt/build

# hadolint ignore=DL3008,DL3015
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    curl \
    git \
    python3.12 \
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

# hadolint ignore=DL3013
RUN pip install --no-cache-dir --break-system-packages pre-commit
