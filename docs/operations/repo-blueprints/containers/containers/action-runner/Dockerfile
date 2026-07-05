FROM ubuntu:24.04@sha256:4fbb8e6a8395de5a7550b33509421a2bafbc0aab6c06ba2cef9ebffbc7092d90
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      jq \
      unzip \
    && rm -rf /var/lib/apt/lists/*

USER 1001
WORKDIR /runner
