FROM registry.k8s.io/kubectl:v1.35.8@sha256:1ec2791a3ddd245559e18a887f2dcd25cdfee7a649c5b73ca2715e3d7f6bf6f8 AS kubectl

FROM ubuntu:26.04@sha256:2260313b31c8c011cd2eebe728008efac1b3982be73eb71348ea2648d2c0e09b

ENV DEBIAN_FRONTEND=noninteractive

# The reaper orchestration script needs a shell and coreutils. kubectl itself is
# copied from the Kubernetes release image so no executable is downloaded by an
# unverified install script.
# hadolint ignore=DL3008
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        coreutils \
        findutils \
        grep \
        procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 65532 nonroot \
    && useradd --no-create-home --no-log-init --uid 65532 --gid 65532 nonroot

COPY --from=kubectl /bin/kubectl /usr/local/bin/kubectl

USER 65532:65532

ENTRYPOINT ["/bin/sh"]
