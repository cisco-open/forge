FROM python:3.14-slim@sha256:7bec7ddcddeff7975d6ba9b4be7dd6f6b2f55e7491539145e2978f7f97ce9144

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      git \
      shellcheck \
    && pip install --no-cache-dir pre-commit yamllint \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
