# =============================================================================
# cibuilder — multi-stage Dockerfile
#
# Base: debian:13-slim (trixie) — pinned digest, updated via Renovate
#
# Run-oriented stages — each contains exactly what one cibuild run needs:
#
#   base              minimal foundation: curl + git + jq + openssh
#   check             base + regctl          (layer diff against registry)
#   build-buildctl    base + buildctl + rootlesskit + runc + binfmt QEMU helpers
#   build-buildx      base + docker CLI + buildx plugin
#   build-nix         base + nix store
#   build-kaniko      base + kaniko executor (runs as root)
#   test-docker       base + docker CLI
#   test-k8s          base + kubectl
#   release           base + regctl + cosign + trivy
#   all               all of the above (lab / development)
#
# All tools installed from GitHub Releases or apt — no Alpine image sources
# K8s-friendly: base/check/build-*/release contain no docker CLI
#
# ZenDIS alignment: swap base image when registry access is available:
#   FROM registry.opencode.de/oci-community/images/zendis/debian:0@sha256:<digest> AS base
# =============================================================================

# ---- global tool versions — single source of truth, updated by Renovate ----
# renovate: datasource=github-releases depName=regclient/regclient
ARG REGCTL_VERSION=0.8.1
# renovate: datasource=github-releases depName=sigstore/cosign
ARG COSIGN_VERSION=3.0.6
# renovate: datasource=github-releases depName=aquasecurity/trivy
ARG TRIVY_VERSION=0.70.0
# renovate: datasource=github-releases depName=moby/buildkit
ARG BUILDKIT_VERSION=0.21.0
# renovate: datasource=github-releases depName=rootless-containers/rootlesskit
ARG ROOTLESSKIT_VERSION=2.3.5

# ---- external image sources — updated by Renovate ----
# renovate: datasource=docker
FROM docker:cli AS dockercli-src

# binfmt QEMU helpers for cross-arch builds (amd64 building arm64 etc.)
# renovate: datasource=docker
FROM tonistiigi/binfmt:buildkit-v10.2.1-64@sha256:4cf4c0ad4919b18996362536883de02420c1010654d3c2a2b63e9b72600fa3a9 AS binfmt-src

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
# BASE — minimal foundation, shared by all stages
#
# Intentionally minimal: curl + git + jq + openssh only
# No build tools, no docker CLI, no registry tools
# =============================================================================
# renovate: datasource=docker
FROM debian:13-slim AS base

LABEL org.opencontainers.image.source="https://github.com/stack4ops/cibuilder"
LABEL org.opencontainers.image.description="Multi CI build environment"
LABEL org.opencontainers.image.licenses="Apache-2.0"

ARG CIBUILDER_BIN_URL=https://github.com/stack4ops/cibuild/archive/refs/heads
ARG CIBUILDER_BIN_REF=main

ENV TZ=Europe/Berlin
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin
ENV HOME=/home/cibuilder
ENV USER=cibuilder
# XDG_RUNTIME_DIR is required by buildctl-daemonless.sh
# was pre-set in moby/buildkit:rootless, must be explicit on debian base
ENV XDG_RUNTIME_DIR=/run/user/1000
# TMPDIR in home — avoids permission issues in rootless context
ENV TMPDIR=/home/cibuilder/.local/tmp
# BUILDKIT_HOST — default socket path for buildctl client
ENV BUILDKIT_HOST=unix:///run/user/1000/buildkit/buildkitd.sock
# buildkitd flags:
# --root: use home dir, avoids /var/lib/buildkit permission issues
# --oci-worker-no-process-sandbox: avoids /run/buildkit permission issues on debian
ENV BUILDKITD_FLAGS="--root=/home/cibuilder/.local/share/buildkit --oci-worker-no-process-sandbox"

RUN groupadd -g 1000 cibuilder \
    && useradd -u 1000 -g cibuilder -m -s /bin/bash cibuilder \
    # runtime dirs for rootlesskit + buildkitd
    && mkdir -p /run/user/1000 /run/buildkit \
    && chown -R 1000:1000 /run/user/1000 /run/buildkit \
    # home dirs matching moby/buildkit:rootless layout
    && mkdir -p /home/cibuilder/.local/tmp /home/cibuilder/.local/share/buildkit \
    && chown -R 1000:1000 /home/cibuilder \
    # subuid/subgid required for rootlesskit user namespace + port-driver
    && echo "cibuilder:100000:65536" | tee /etc/subuid | tee /etc/subgid

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       fuse3 \
       git \
       jq \
       netcat-openbsd \
       openssh-client \
       pigz \
       tzdata \
       xz-utils \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone \
    && rm -rf /var/lib/apt/lists/*

# ca certs for localregistry (lab)
# .crt extension required by update-ca-certificates on Debian
COPY ./localregistry/root.pem    /usr/local/share/ca-certificates/root.crt
COPY ./localregistry/signing.pem /usr/local/share/ca-certificates/signing.crt
RUN update-ca-certificates

COPY ./cibuild_entrypoint.sh /usr/local/bin/cibuild_entrypoint.sh
RUN chmod 755 /usr/local/bin/cibuild_entrypoint.sh

USER cibuilder

RUN cd /home/cibuilder \
    && curl -fsSL "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}.tar.gz" \
       | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin" \
    && chmod -R 755 bin

ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# CHECK — base + regctl
# cibuild -r check: layer diff between base image and last built image
# =============================================================================
FROM base AS check

ARG TARGETARCH

ARG REGCTL_VERSION

USER root

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/regclient/regclient/releases/download/v${REGCTL_VERSION}/regctl-linux-${ARCH}" \
       > /usr/local/bin/regctl \
    && chmod +x /usr/local/bin/regctl

USER cibuilder

ENV CIBUILD_RUN_CMD=check
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILD-BUILDCTL — base + buildctl + rootlesskit
# cibuild -r build with CIBUILD_BUILD_CLIENT=buildctl (default)
# =============================================================================
FROM base AS build-buildctl

ARG TARGETARCH

USER root

ARG BUILDKIT_VERSION
ARG ROOTLESSKIT_VERSION

# uidmap + runc via apt — setuid caps cannot survive COPY --from
# runc: OCI worker required by buildkitd
# libcap2-bin: provides setcap for newuidmap/newgidmap
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       fuse-overlayfs \
       libcap2-bin \
       runc \
       uidmap \
       xz-utils \
    && setcap cap_setuid=ep /usr/bin/newuidmap cap_setgid=ep /usr/bin/newgidmap \
    && chmod 0755 /usr/bin/newuidmap /usr/bin/newgidmap \
    && rm -rf /var/lib/apt/lists/*

# buildkit (buildkitd + buildctl) — from GitHub releases, native Linux binary
RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ --strip-components=1 bin/buildkitd bin/buildctl \
    && chmod +x /usr/local/bin/buildkitd /usr/local/bin/buildctl

# rootlesskit — from GitHub releases, native Linux binary
# arch naming: amd64 → x86_64, arm64 → aarch64
RUN case "$TARGETARCH" in \
      amd64) ARCH="x86_64" ;; \
      arm64) ARCH="aarch64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/rootless-containers/rootlesskit/releases/download/v${ROOTLESSKIT_VERSION}/rootlesskit-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ rootlesskit \
    && chmod +x /usr/local/bin/rootlesskit

# binfmt QEMU helpers — enables cross-arch builds (e.g. arm64 on amd64 runner)
# loongarch64/mips64/mips64el excluded (matching moby/buildkit:rootless filter)
COPY --from=binfmt-src / /usr/local/bin/

COPY ./buildctl-daemonless.sh /usr/local/bin/buildctl-daemonless.sh
RUN chmod 755 /usr/local/bin/buildctl-daemonless.sh

USER cibuilder

RUN mkdir -p /home/cibuilder/.config/buildkit \
    && touch /home/cibuilder/.config/buildkit/buildkitd.toml

ENV CIBUILD_RUN_CMD=build
ENV CIBUILD_BUILD_CLIENT=buildctl
# buildkit state volume — matching moby/buildkit:rootless VOLUME declaration
VOLUME /home/cibuilder/.local/share/buildkit
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILD-BUILDX — base + docker CLI + buildx plugin
# cibuild -r build with CIBUILD_BUILD_CLIENT=buildx
# requires DinD or external docker daemon
# =============================================================================
FROM base AS build-buildx

USER root

COPY --from=dockercli-src /usr/local/bin/docker \
     /usr/local/bin/docker
COPY --from=dockercli-src /usr/local/libexec/docker/cli-plugins/docker-buildx \
     /usr/local/libexec/docker/cli-plugins/docker-buildx

USER cibuilder

ENV CIBUILD_RUN_CMD=build
ENV CIBUILD_BUILD_CLIENT=buildx
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILD-NIX — base + nix store
# cibuild -r build with CIBUILD_BUILD_CLIENT=nix
# K8s-friendly: no docker CLI, no buildkit daemon
# =============================================================================
FROM base AS build-nix

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin:/home/cibuilder/.nix-profile/bin

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN install -d -m 755 /nix && chown 1000:1000 /nix

COPY --from=nix-installer --chown=1000:1000 /nix                         /nix
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.nix-profile /home/cibuilder/.nix-profile
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.config/nix  /home/cibuilder/.config/nix

USER cibuilder

ENV CIBUILD_RUN_CMD=build
ENV CIBUILD_BUILD_CLIENT=nix
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILD-KANIKO — base + kaniko executor
# cibuild -r build with CIBUILD_BUILD_CLIENT=kaniko
# K8s-friendly: no docker CLI — runs as root
# =============================================================================
FROM base AS build-kaniko

USER root

RUN mkdir -p /kaniko && chmod 777 /kaniko

COPY --from=kaniko-src /kaniko/executor /kaniko/executor

# kaniko requires root — intentionally no USER cibuilder

ENV CIBUILD_RUN_CMD=build
ENV CIBUILD_BUILD_CLIENT=kaniko
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# TEST-DOCKER — base + docker CLI
# cibuild -r test with CIBUILD_TEST_BACKEND=docker
# requires DinD sidecar in CI
# =============================================================================
FROM base AS test-docker

USER root

COPY --from=dockercli-src /usr/local/bin/docker \
     /usr/local/bin/docker

USER cibuilder

ENV CIBUILD_RUN_CMD=test
ENV CIBUILD_TEST_BACKEND=docker
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# TEST-K8S — base + kubectl
# cibuild -r test with CIBUILD_TEST_BACKEND=kubernetes
# K8s-friendly: no docker CLI
# =============================================================================
FROM base AS test-k8s

ARG TARGETARCH

USER root

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" \
       > /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

USER cibuilder

ENV CIBUILD_RUN_CMD=test
ENV CIBUILD_TEST_BACKEND=kubernetes
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# RELEASE — base + regctl + cosign + trivy
# cibuild -r release: index assembly + signing + SBOM
# SBOM always via trivy — no docker buildx imagetools dependency
# K8s-friendly: no docker CLI
# =============================================================================
FROM base AS release

ARG TARGETARCH

# tool versions — updated by Renovate via customManagers
ARG REGCTL_VERSION
ARG COSIGN_VERSION
ARG TRIVY_VERSION

USER root

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
# trivy uses non-standard arch naming: amd64 -> 64bit, arm64 -> ARM64
RUN case "$TARGETARCH" in \
      amd64) TRIVY_ARCH="64bit" ;; \
      arm64) TRIVY_ARCH="ARM64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" \
       | tar xz trivy \
    && mv trivy /usr/local/bin/trivy

USER cibuilder

ENV CIBUILD_RUN_CMD=release
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# ALL — all stages combined (lab / development)
# equivalent to cibuild -r all — use for local lab
# =============================================================================
FROM base AS all

ARG TARGETARCH

# tool versions — updated by Renovate via customManagers
ARG REGCTL_VERSION
ARG COSIGN_VERSION
ARG TRIVY_VERSION

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin:/home/cibuilder/.nix-profile/bin

USER root

# uidmap for rootlesskit + runc for buildkitd OCI worker
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       fuse-overlayfs \
       libcap2-bin \
       runc \
       uidmap \
       xz-utils \
    && setcap cap_setuid=ep /usr/bin/newuidmap cap_setgid=ep /usr/bin/newgidmap \
    && chmod 0755 /usr/bin/newuidmap /usr/bin/newgidmap \
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

# trivy
RUN case "$TARGETARCH" in \
      amd64) TRIVY_ARCH="64bit" ;; \
      arm64) TRIVY_ARCH="ARM64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" \
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

# buildkit (buildkitd + buildctl) — from GitHub releases, native Linux binary
ARG BUILDKIT_VERSION
RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ --strip-components=1 bin/buildkitd bin/buildctl \
    && chmod +x /usr/local/bin/buildkitd /usr/local/bin/buildctl

# rootlesskit — from GitHub releases, native Linux binary
ARG ROOTLESSKIT_VERSION
RUN case "$TARGETARCH" in \
      amd64) ARCH="x86_64" ;; \
      arm64) ARCH="aarch64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/rootless-containers/rootlesskit/releases/download/v${ROOTLESSKIT_VERSION}/rootlesskit-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ rootlesskit \
    && chmod +x /usr/local/bin/rootlesskit

# binfmt QEMU helpers — enables cross-arch builds (e.g. arm64 on amd64 runner)
COPY --from=binfmt-src / /usr/local/bin/

COPY ./buildctl-daemonless.sh /usr/local/bin/buildctl-daemonless.sh
RUN chmod 755 /usr/local/bin/buildctl-daemonless.sh

# docker CLI + buildx plugin
COPY --from=dockercli-src /usr/local/bin/docker \
     /usr/local/bin/docker
COPY --from=dockercli-src /usr/local/libexec/docker/cli-plugins/docker-buildx \
     /usr/local/libexec/docker/cli-plugins/docker-buildx

# nix
RUN install -d -m 755 /nix && chown 1000:1000 /nix
COPY --from=nix-installer --chown=1000:1000 /nix                         /nix
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.nix-profile /home/cibuilder/.nix-profile
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.config/nix  /home/cibuilder/.config/nix

# kaniko
RUN mkdir -p /kaniko && chmod 777 /kaniko
COPY --from=kaniko-src /kaniko/executor /kaniko/executor

USER cibuilder

RUN mkdir -p /home/cibuilder/.config/buildkit \
    && touch /home/cibuilder/.config/buildkit/buildkitd.toml

ENV CIBUILD_RUN_CMD=all
ENTRYPOINT ["cibuild_entrypoint.sh"]