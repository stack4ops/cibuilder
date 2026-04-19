# =============================================================================
# cibuilder — multi-stage Dockerfile
#
# Base: debian:13-slim (trixie) — pinned digest, updated via Renovate
#
# Stages:
#   nix-installer  helper: installs nix single-user as uid 1000
#   base           shared foundation: common tools + cibuild libs
#   nix            base + nix store (nix build backend)
#   buildctl       base + buildkit binaries + rootlesskit
#   buildx         base + docker CLI + buildx plugin
#   kaniko         base + kaniko executor (root)
#   full           all backends combined (lab / development)
#
# ZenDIS alignment: swap base image when registry access is available:
#   FROM registry.opencode.de/oci-community/images/zendis/debian:0@sha256:<digest> AS base
#
# Pin digests after first build:
#   regctl image digest debian:13-slim
#   regctl image digest moby/buildkit:rootless
#   regctl image digest docker:cli
#   regctl image digest martizih/kaniko:v1.27.2
# =============================================================================

# ---- external image sources — updated by Renovate ----
# renovate: datasource=docker
FROM moby/buildkit:rootless AS buildkit-src

# renovate: datasource=docker
FROM docker:cli AS dockercli-src

# renovate: datasource=docker
FROM martizih/kaniko:v1.27.2 AS kaniko-src

# =============================================================================
# NIX INSTALLER — installs nix single-user as uid 1000
# =============================================================================
# renovate: datasource=docker
FROM debian:13-slim AS nix-installer

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN install -d -m 755 /nix \
    && chown 1000:1000 /nix

RUN groupadd -g 1000 cibuilder \
    && useradd -u 1000 -g cibuilder -m -s /bin/bash cibuilder

USER cibuilder

RUN curl -sSL https://nixos.org/nix/install | sh -s -- \
      --no-daemon \
      --no-modify-profile

RUN mkdir -p /home/cibuilder/.config/nix \
    && printf 'experimental-features = nix-command flakes\n' \
       > /home/cibuilder/.config/nix/nix.conf

# =============================================================================
# BASE — shared foundation for all cibuilder variants
# =============================================================================
# renovate: datasource=docker
FROM debian:13-slim AS base

LABEL org.opencontainers.image.source="https://github.com/stack4ops/cibuilder"
LABEL org.opencontainers.image.description="Multi CI build environment"
LABEL org.opencontainers.image.licenses="Apache-2.0"

ARG TARGETARCH
ARG CIBUILDER_BIN_URL=https://github.com/stack4ops/cibuild/archive/refs/heads
ARG CIBUILDER_BIN_REF=main

# tool versions — updated by Renovate via customManagers
# renovate: datasource=github-releases depName=regclient/regclient
ARG REGCTL_VERSION=0.8.1
# renovate: datasource=github-releases depName=sigstore/cosign
ARG COSIGN_VERSION=3.0.6
# renovate: datasource=github-releases depName=aquasecurity/trivy
ARG TRIVY_VERSION=0.70.0

ENV TZ=Europe/Berlin
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin

RUN groupadd -g 1000 cibuilder \
    && useradd -u 1000 -g cibuilder -m -s /bin/bash cibuilder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       git \
       jq \
       openssh-client \
       tzdata \
       xz-utils \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# regctl
RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/regclient/regclient/releases/download/v${REGCTL_VERSION}/regctl-linux-${ARCH}" \
       > /usr/local/bin/regctl \
    && chmod +x /usr/local/bin/regctl

# cosign
RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH}" \
       > /usr/local/bin/cosign \
    && chmod +x /usr/local/bin/cosign

# trivy — pinned to v0.70.0+ (v0.69.4/5/6 were compromised March 2026)
RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${ARCH^^}.tar.gz" \
       | tar xz trivy \
    && mv trivy /usr/local/bin/trivy

# kubectl
RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" \
       > /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

# ca certs for localregistry (lab)
COPY ./localregistry/root.pem    /usr/local/share/ca-certificates/root.pem
COPY ./localregistry/signing.pem /usr/local/share/ca-certificates/signing.pem
RUN update-ca-certificates

COPY ./cibuild_entrypoint.sh /usr/local/bin/cibuild_entrypoint.sh
RUN chmod 755 /usr/local/bin/cibuild_entrypoint.sh

USER cibuilder

RUN cd /home/cibuilder \
    && curl -fsSL "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}.tar.gz" \
       | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin" \
    && chmod -R 755 bin

# =============================================================================
# NIX — base + nix store
# =============================================================================
FROM base AS nix

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin:/home/cibuilder/.nix-profile/bin

USER root

RUN install -d -m 755 /nix && chown 1000:1000 /nix

COPY --from=nix-installer --chown=1000:1000 /nix                         /nix
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.nix-profile /home/cibuilder/.nix-profile
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.config/nix  /home/cibuilder/.config/nix

USER cibuilder

ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILDCTL — base + buildkit binaries + rootlesskit
# =============================================================================
FROM base AS buildctl

USER root

COPY --from=buildkit-src /usr/bin/buildkitd   /usr/local/bin/buildkitd
COPY --from=buildkit-src /usr/bin/buildctl    /usr/local/bin/buildctl
COPY --from=buildkit-src /usr/bin/rootlesskit /usr/local/bin/rootlesskit
COPY --from=buildkit-src /usr/bin/newuidmap   /usr/local/bin/newuidmap
COPY --from=buildkit-src /usr/bin/newgidmap   /usr/local/bin/newgidmap

COPY ./buildctl-daemonless.sh /usr/local/bin/buildctl-daemonless.sh
RUN chmod 755 /usr/local/bin/buildctl-daemonless.sh

USER cibuilder

RUN mkdir -p /home/cibuilder/.config/buildkit \
    && touch /home/cibuilder/.config/buildkit/buildkitd.toml

ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILDX — base + docker CLI + buildx plugin
# =============================================================================
FROM base AS buildx

USER root

COPY --from=dockercli-src /usr/local/bin/docker \
     /usr/local/bin/docker
COPY --from=dockercli-src /usr/local/libexec/docker/cli-plugins/docker-buildx \
     /usr/local/libexec/docker/cli-plugins/docker-buildx

USER cibuilder

ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# KANIKO — base + kaniko executor (runs as root)
# =============================================================================
FROM base AS kaniko

USER root

RUN mkdir -p /kaniko && chmod 777 /kaniko

COPY --from=kaniko-src /kaniko/executor /kaniko/executor

# kaniko requires root — intentionally no USER cibuilder

ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# FULL — all backends (lab / development)
# =============================================================================
FROM base AS full

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin:/home/cibuilder/.nix-profile/bin

USER root

# nix
RUN install -d -m 755 /nix && chown 1000:1000 /nix
COPY --from=nix-installer --chown=1000:1000 /nix                         /nix
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.nix-profile /home/cibuilder/.nix-profile
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.config/nix  /home/cibuilder/.config/nix

# buildctl + rootlesskit
COPY --from=buildkit-src /usr/bin/buildkitd   /usr/local/bin/buildkitd
COPY --from=buildkit-src /usr/bin/buildctl    /usr/local/bin/buildctl
COPY --from=buildkit-src /usr/bin/rootlesskit /usr/local/bin/rootlesskit
COPY --from=buildkit-src /usr/bin/newuidmap   /usr/local/bin/newuidmap
COPY --from=buildkit-src /usr/bin/newgidmap   /usr/local/bin/newgidmap

COPY ./buildctl-daemonless.sh /usr/local/bin/buildctl-daemonless.sh
RUN chmod 755 /usr/local/bin/buildctl-daemonless.sh

# docker + buildx
COPY --from=dockercli-src /usr/local/bin/docker \
     /usr/local/bin/docker
COPY --from=dockercli-src /usr/local/libexec/docker/cli-plugins/docker-buildx \
     /usr/local/libexec/docker/cli-plugins/docker-buildx

# kaniko
RUN mkdir -p /kaniko && chmod 777 /kaniko
COPY --from=kaniko-src /kaniko/executor /kaniko/executor

USER cibuilder

RUN mkdir -p /home/cibuilder/.config/buildkit \
    && touch /home/cibuilder/.config/buildkit/buildkitd.toml

ENTRYPOINT ["cibuild_entrypoint.sh"]