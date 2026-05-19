# syntax=docker/dockerfile:1
# =============================================================================
# cibuilder — multi-stage Dockerfile
#
# Base: docker.io/library/debian:13-slim (trixie) — pinned digest, updated via Renovate
#
# Run-oriented stages — each contains exactly what one cibuild run needs:
#
#   base              minimal foundation: curl + git + jq + openssh
#   check             base + regctl          (layer diff against registry)
#   build-buildctl    base + buildctl + rootlesskit + runc + buildkit-qemu-*
#   build-buildx      base + docker CLI + buildx plugin
#   build-nix         base + nix store + regctl
#   build-kaniko      base + kaniko executor (runs as root)
#   test-docker       base + docker CLI
#   test-k8s          base + kubectl
#   release           base + regctl + cosign + trivy
#   update-caches     base + trivy (scheduled cache updates)
#   all               all of the above (lab / development)
#
# All tools installed from GitHub Releases or apt — pinned versions, updated by Renovate
# K8s-friendly: base/check/build-*/release contain no docker CLI
#
# Maintenance Notes:
# for getting initial digest:
#   regctl manifest head docker.io/library/debian:13-slim
# for getting apt package versions:
#   ./deb_bin_version.sh 13 <package>
# =============================================================================

# ---- global tool versions — single source of truth, updated by Renovate ----

ARG REGCTL_VERSION=0.11.3 # renovate: datasource=github-releases depName=regclient/regclient
ARG COSIGN_VERSION=3.0.6 # renovate: datasource=github-releases depName=sigstore/cosign
ARG TRIVY_VERSION=0.70.0 # renovate: datasource=github-releases depName=aquasecurity/trivy
ARG BUILDKIT_VERSION=0.29.0 # renovate: datasource=github-releases depName=moby/buildkit
ARG ROOTLESSKIT_VERSION=2.3.5 # renovate: datasource=github-releases depName=rootless-containers/rootlesskit
ARG KUBECTL_VERSION=1.36.1 # renovate: datasource=github-tags depName=kubernetes/kubernetes

# ---- debian packages — updated by Renovate ----
ARG CA_CERTIFICATES_VERSION=20250419 # renovate: suite=trixie depName=ca-certificates
ARG CURL_VERSION=8.14.1-2+deb13u3 # renovate: suite=trixie depName=curl
ARG XZ_UTILS_VERSION=5.8.1-1 # renovate: suite=trixie depName=xz-utils
ARG GZIP_VERSION=1.13-1 # renovate: suite=trixie depName=gzip
ARG LIBCAP2_BIN_VERSION=1:2.75-10+deb13u1+b1 # renovate: suite=trixie depName=libcap2-bin
ARG RUNC_VERSION=1.1.15+ds1-2+b4 # renovate: suite=trixie depName=runc
ARG UIDMAP_VERSION=1:4.17.4-2 # renovate: suite=trixie depName=uidmap
ARG FUSE_OVERLAYFS_VERSION=1.14-1+b1 # renovate: suite=trixie depName=fuse-overlayfs
ARG GIT_VERSION=1:2.47.3-0+deb13u1 # renovate: suite=trixie depName=git
ARG JQ_VERSION=1.7.1-6+deb13u2 # renovate: suite=trixie depName=jq
ARG NETCAT_VERSION=1.229-1 # renovate: suite=trixie depName=netcat-openbsd
ARG OPENSSH_CLIENT_VERSION=1:10.0p1-7+deb13u4 # renovate: suite=trixie depName=openssh-client
ARG PIGZ_VERSION=2.8-1 # renovate: suite=trixie depName=pigz

# ---- external image sources — updated by Renovate ----
FROM docker:cli AS dockercli-src # renovate: datasource=docker
FROM martizih/kaniko:v1.27.2 AS kaniko-src # renovate: datasource=docker

# =============================================================================
# NIX INSTALLER — installs nix single-user as uid 1000
# Uses ZenDiS base only for the installer stage — nix install needs curl + xz
# =============================================================================

FROM docker.io/library/debian:13-slim@sha256:109e2c65005bf160609e4ba6acf7783752f8502ad218e298253428690b9eaa4b AS nix-installer

ENV DEBIAN_FRONTEND=noninteractive

ARG CURL_VERSION
ARG CA_CERTIFICATES_VERSION
ARG XZ_UTILS_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl=${CURL_VERSION} \
       ca-certificates=${CA_CERTIFICATES_VERSION} \
       xz-utils=${XZ_UTILS_VERSION} \
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

FROM docker.io/library/debian:13-slim@sha256:109e2c65005bf160609e4ba6acf7783752f8502ad218e298253428690b9eaa4b AS base

LABEL org.opencontainers.image.source="https://github.com/stack4ops/cibuilder"
LABEL org.opencontainers.image.description="Multi CI build environment"
LABEL org.opencontainers.image.licenses="Apache-2.0"

ARG CIBUILDER_BIN_URL=https://github.com/stack4ops/cibuild/archive/refs/heads
ARG CIBUILDER_BIN_REF=main

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin
ENV HOME=/home/cibuilder
ENV USER=cibuilder
# XDG_RUNTIME_DIR is required by buildctl-daemonless.sh
ENV XDG_RUNTIME_DIR=/run/user/1000
# TMPDIR in home — avoids permission issues in rootless context
ENV TMPDIR=/home/cibuilder/.local/tmp
# BUILDKIT_HOST — default socket path for buildctl client
ENV BUILDKIT_HOST=unix:///run/user/1000/buildkit/buildkitd.sock
# buildkitd flags
ENV BUILDKITD_FLAGS="--root=/home/cibuilder/.local/share/buildkit --oci-worker-no-process-sandbox"

ARG CURL_VERSION
ARG CA_CERTIFICATES_VERSION
ARG XZ_UTILS_VERSION
ARG GZIP_VERSION
ARG FUSE_OVERLAYFS_VERSION
ARG GIT_VERSION
ARG JQ_VERSION
ARG NETCAT_VERSION
ARG OPENSSH_CLIENT_VERSION
ARG PIGZ_VERSION

RUN groupadd -g 1000 cibuilder \
    && useradd -u 1000 -g cibuilder -m -s /bin/bash cibuilder \
    && mkdir -p /run/user/1000 /run/buildkit \
    && chown -R 1000:1000 /run/user/1000 /run/buildkit \
    && mkdir -p /home/cibuilder/.local/tmp /home/cibuilder/.local/share/buildkit \
    && mkdir -p \
       /home/cibuilder/.cache/trivy \
       /home/cibuilder/.cache/nix \
       /home/cibuilder/.cache/cosign \
       /home/cibuilder/.docker \
       /home/cibuilder/.ssh \
       /home/cibuilder/.config/regctl \
    && chmod 700 /home/cibuilder/.ssh \
    && chown -R 1000:1000 /home/cibuilder \
    && printf 'cibuilder:100000:65536\nroot:100000:65536\n' | tee /etc/subuid > /etc/subgid

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl=${CURL_VERSION} \
       ca-certificates=${CA_CERTIFICATES_VERSION} \
       fuse-overlayfs=${FUSE_OVERLAYFS_VERSION} \
       git=${GIT_VERSION} \
       jq=${JQ_VERSION} \
       netcat-openbsd=${NETCAT_VERSION} \
       openssh-client=${OPENSSH_CLIENT_VERSION} \
       pigz=${PIGZ_VERSION} \
       xz-utils=${XZ_UTILS_VERSION} \
       gzip=${GZIP_VERSION} \
    && rm -rf /var/lib/apt/lists/*

# ca certs for localregistry (lab)
# .crt extension required by update-ca-certificates on Debian
COPY ./localregistry/root.pem    /usr/local/share/ca-certificates/root.crt
COPY ./localregistry/signing.pem /usr/local/share/ca-certificates/signing.crt
RUN update-ca-certificates

COPY ./cibuild_entrypoint.sh /usr/local/bin/cibuild_entrypoint.sh
RUN chmod 755 /usr/local/bin/cibuild_entrypoint.sh

USER cibuilder
ARG FORCE_DOWNLOAD_CIBUILD
RUN cd /home/cibuilder \
    && curl -fsSL "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}.tar.gz" \
       | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin" \
    && chmod -R 755 bin

ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# CHECK — base + regctl
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
ENV CIBUILDER_ROOTLESS_KIT=0
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILD-BUILDCTL — base + buildctl + rootlesskit + buildkit-qemu-*
# =============================================================================
FROM base AS build-buildctl

ARG TARGETARCH
ARG BUILDKIT_VERSION
ARG ROOTLESSKIT_VERSION

ARG LIBCAP2_BIN_VERSION
ARG RUNC_VERSION
ARG UIDMAP_VERSION

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libcap2-bin=${LIBCAP2_BIN_VERSION} \
       runc=${RUNC_VERSION} \
       uidmap=${UIDMAP_VERSION} \
    && setcap cap_setuid=ep /usr/bin/newuidmap cap_setgid=ep /usr/bin/newgidmap \
    && chmod 0755 /usr/bin/newuidmap /usr/bin/newgidmap \
    && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ --strip-components=1 \
           --wildcards \
           bin/buildkitd \
           bin/buildctl \
           'bin/buildkit-qemu-*' \
    && chmod +x /usr/local/bin/buildkitd /usr/local/bin/buildctl \
    && chmod +x /usr/local/bin/buildkit-qemu-* 2>/dev/null || true \
    && ls /usr/local/bin/buildkit-qemu-* 2>/dev/null \
       || echo "WARNING: no buildkit-qemu-* found — cross-arch builds will require host binfmt_misc"

RUN case "$TARGETARCH" in \
      amd64) ARCH="x86_64" ;; \
      arm64) ARCH="aarch64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/rootless-containers/rootlesskit/releases/download/v${ROOTLESSKIT_VERSION}/rootlesskit-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ rootlesskit \
    && chmod +x /usr/local/bin/rootlesskit

COPY ./buildctl-daemonless.sh /usr/local/bin/buildctl-daemonless.sh
RUN chmod 755 /usr/local/bin/buildctl-daemonless.sh

USER cibuilder

RUN mkdir -p /home/cibuilder/.config/buildkit \
    && touch /home/cibuilder/.config/buildkit/buildkitd.toml

ENV CIBUILD_RUN_CMD=build
ENV CIBUILD_BUILD_CLIENT=buildctl
ENV CIBUILDER_ROOTLESS_KIT=1
VOLUME /home/cibuilder/.local/share/buildkit
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILD-BUILDX — base + docker CLI + buildx plugin
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
ENV CIBUILDER_ROOTLESS_KIT=0
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILD-NIX — base + nix store + regctl
# =============================================================================
FROM base AS build-nix

ARG TARGETARCH
ARG REGCTL_VERSION

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin:/home/cibuilder/.nix-profile/bin

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

RUN install -d -m 755 /nix && chown 1000:1000 /nix

COPY --from=nix-installer --chown=1000:1000 /nix                         /nix
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.nix-profile /home/cibuilder/.nix-profile
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.config/nix  /home/cibuilder/.config/nix

ARG NIX_ATTIC_CHANNEL=nixpkgs-unstable # renovate: datasource=nix depName=attic-client
RUN mkdir -p /root/.config/nix \
  && echo "build-users-group =" > /root/.config/nix/nix.conf \
  && HOME=/root \
      nix-env \
        --profile /nix/var/nix/profiles/attic-client \
        -iA attic-client \
        -f "https://nixos.org/channels/${NIX_ATTIC_CHANNEL}/nixexprs.tar.xz" \
  && printf '#!/bin/sh\nexec /nix/var/nix/profiles/attic-client/bin/attic "$@"\n' \
       > /usr/local/bin/attic \
  && chmod 755 /usr/local/bin/attic \
  && nix-collect-garbage -d \
  && nix-store --optimise \
  && chown -R 1000:1000 /nix/var/nix/profiles/attic-client

USER cibuilder

VOLUME /nix/store
VOLUME /nix/var/nix/db

ENV CIBUILD_RUN_CMD=build
ENV CIBUILD_BUILD_CLIENT=nix
ENV CIBUILDER_ROOTLESS_KIT=0
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# BUILD-KANIKO — base + kaniko executor (runs as root)
# =============================================================================
FROM base AS build-kaniko

USER root

RUN mkdir -p /kaniko && chmod 777 /kaniko
COPY --from=kaniko-src /kaniko/executor /kaniko/executor

ENV CIBUILD_RUN_CMD=build
ENV CIBUILD_BUILD_CLIENT=kaniko
ENV CIBUILDER_ROOTLESS_KIT=0
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# TEST-DOCKER — base + docker CLI
# =============================================================================
FROM base AS test-docker

USER root

COPY --from=dockercli-src /usr/local/bin/docker \
     /usr/local/bin/docker

USER cibuilder

ENV CIBUILD_RUN_CMD=test
ENV CIBUILD_TEST_BACKEND=docker
ENV CIBUILDER_ROOTLESS_KIT=0
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# TEST-K8S — base + kubectl
# =============================================================================
FROM base AS test-k8s

ARG TARGETARCH
ARG KUBECTL_VERSION

USER root

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
       > /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

USER cibuilder

ENV CIBUILD_RUN_CMD=test
ENV CIBUILD_TEST_BACKEND=kubernetes
ENV CIBUILDER_ROOTLESS_KIT=0
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# RELEASE — base + regctl + cosign + trivy
# trivy pinned to v0.70.0+ (v0.69.4/5/6 were compromised March 2026)
# =============================================================================
FROM base AS release

ARG TARGETARCH
ARG REGCTL_VERSION
ARG COSIGN_VERSION
ARG TRIVY_VERSION

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

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH}" \
       > /usr/local/bin/cosign \
    && chmod +x /usr/local/bin/cosign

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
ENV CIBUILDER_ROOTLESS_KIT=0
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# UPDATE-CACHES — base + trivy
# =============================================================================
FROM base AS update-caches

ARG TARGETARCH
ARG TRIVY_VERSION

USER root

RUN case "$TARGETARCH" in \
      amd64) ARCH="64bit" ;; \
      arm64) ARCH="ARM64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ trivy \
    && chmod +x /usr/local/bin/trivy

USER cibuilder

ENV CIBUILD_RUN_CMD=update-caches
ENV CIBUILD_UPDATE_CACHES_ENABLED=1
ENV CIBUILD_UPDATE_CACHES_TRIVY_DB=1
ENV CIBUILDER_ROOTLESS_KIT=0
ENTRYPOINT ["cibuild_entrypoint.sh"]

# =============================================================================
# ALL — all stages combined (lab / development)
# =============================================================================
FROM base AS all

ARG TARGETARCH
ARG REGCTL_VERSION
ARG COSIGN_VERSION
ARG TRIVY_VERSION
ARG BUILDKIT_VERSION
ARG ROOTLESSKIT_VERSION
ARG KUBECTL_VERSION

ARG LIBCAP2_BIN_VERSION
ARG RUNC_VERSION
ARG UIDMAP_VERSION

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin:/home/cibuilder/.nix-profile/bin

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       libcap2-bin=${LIBCAP2_BIN_VERSION} \
       runc=${RUNC_VERSION} \
       uidmap=${UIDMAP_VERSION} \
    && setcap cap_setuid=ep /usr/bin/newuidmap cap_setgid=ep /usr/bin/newgidmap \
    && chmod 0755 /usr/bin/newuidmap /usr/bin/newgidmap \
    && rm -rf /var/lib/apt/lists/*

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/regclient/regclient/releases/download/v${REGCTL_VERSION}/regctl-linux-${ARCH}" \
       > /usr/local/bin/regctl \
    && chmod +x /usr/local/bin/regctl

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/sigstore/cosign/releases/download/v${COSIGN_VERSION}/cosign-linux-${ARCH}" \
       > /usr/local/bin/cosign \
    && chmod +x /usr/local/bin/cosign

RUN case "$TARGETARCH" in \
      amd64) TRIVY_ARCH="64bit" ;; \
      arm64) TRIVY_ARCH="ARM64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-${TRIVY_ARCH}.tar.gz" \
       | tar xz trivy \
    && mv trivy /usr/local/bin/trivy

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
   esac \
   && curl -fsSL \
      "https://dl.k8s.io/release/v${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl" \
      > /usr/local/bin/kubectl \
   && chmod +x /usr/local/bin/kubectl

RUN case "$TARGETARCH" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ --strip-components=1 \
           --wildcards \
           bin/buildkitd \
           bin/buildctl \
           'bin/buildkit-qemu-*' \
    && chmod +x /usr/local/bin/buildkitd /usr/local/bin/buildctl \
    && chmod +x /usr/local/bin/buildkit-qemu-* 2>/dev/null || true \
    && ls /usr/local/bin/buildkit-qemu-* 2>/dev/null \
       || echo "WARNING: no buildkit-qemu-* found — cross-arch builds will require host binfmt_misc"

RUN case "$TARGETARCH" in \
      amd64) ARCH="x86_64" ;; \
      arm64) ARCH="aarch64" ;; \
      *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;; \
    esac \
    && curl -fsSL \
       "https://github.com/rootless-containers/rootlesskit/releases/download/v${ROOTLESSKIT_VERSION}/rootlesskit-${ARCH}.tar.gz" \
       | tar xz -C /usr/local/bin/ rootlesskit \
    && chmod +x /usr/local/bin/rootlesskit

COPY ./buildctl-daemonless.sh /usr/local/bin/buildctl-daemonless.sh
RUN chmod 755 /usr/local/bin/buildctl-daemonless.sh

COPY --from=dockercli-src /usr/local/bin/docker \
     /usr/local/bin/docker
COPY --from=dockercli-src /usr/local/libexec/docker/cli-plugins/docker-buildx \
     /usr/local/libexec/docker/cli-plugins/docker-buildx

RUN install -d -m 755 /nix && chown 1000:1000 /nix
COPY --from=nix-installer --chown=1000:1000 /nix                         /nix
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.nix-profile /home/cibuilder/.nix-profile
COPY --from=nix-installer --chown=1000:1000 /home/cibuilder/.config/nix  /home/cibuilder/.config/nix

ARG NIX_ATTIC_CHANNEL=nixpkgs-unstable # renovate: datasource=nix depName=attic-client
RUN mkdir -p /root/.config/nix \
  && echo "build-users-group =" > /root/.config/nix/nix.conf \
  && HOME=/root \
      nix-env \
        --profile /nix/var/nix/profiles/attic-client \
        -iA attic-client \
        -f "https://nixos.org/channels/${NIX_ATTIC_CHANNEL}/nixexprs.tar.xz" \
  && printf '#!/bin/sh\nexec /nix/var/nix/profiles/attic-client/bin/attic "$@"\n' \
       > /usr/local/bin/attic \
  && chmod 755 /usr/local/bin/attic \
  && nix-collect-garbage -d \
  && nix-store --optimise \
  && chown -R 1000:1000 /nix/var/nix/profiles/attic-client

RUN mkdir -p /kaniko && chmod 777 /kaniko
COPY --from=kaniko-src /kaniko/executor /kaniko/executor

USER cibuilder

RUN mkdir -p /home/cibuilder/.config/buildkit \
    && touch /home/cibuilder/.config/buildkit/buildkitd.toml

ENV CIBUILD_RUN_CMD=all
ENV CIBUILDER_ROOTLESS_KIT=1
VOLUME /home/cibuilder/.local/share/buildkit
ENTRYPOINT ["cibuild_entrypoint.sh"]