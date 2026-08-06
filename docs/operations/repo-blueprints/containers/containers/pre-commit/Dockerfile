FROM python:3.14-slim@sha256:a7fb1e634c4a578f9e0bd6327f11a3cde11b7a9395f48e24360c0988bcc5c2bc

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      git \
      shellcheck \
    && pip install --no-cache-dir pre-commit yamllint \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
