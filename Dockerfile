FROM docker:cli AS dockercli
FROM martizih/kaniko:latest AS kaniko
FROM moby/buildkit:rootless

LABEL org.opencontainers.image.source="https://github.com/stack4ops/cibuilder"
LABEL org.opencontainers.image.description="Multi CI build environment with embedded cibuild libs"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="1.0.0"

# Build arguments for configuration
ARG TARGETARCH
ARG HTTP_PROXY=
ARG HTTPS_PROXY=
ARG http_proxy=
ARG https_proxy=

ARG CIBUILDER_BIN_URL=https://github.com/stack4ops/cibuild/archive/refs/heads
ARG CIBUILDER_BIN_REF=main

USER root

ENV TZ=Europe/Berlin \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/user/bin

RUN <<'EOF'
set -e

apk add --no-cache \
    ca-certificates \
    openssh \
    tzdata \
    curl \
    bash \
    jq \
    git

EOF

# Copy Docker CLI and BuildKit Buildx from dockercli stage
COPY --from=dockercli    /usr/local/bin/docker                               /usr/local/bin/docker
COPY --from=dockercli    /usr/local/libexec/docker/cli-plugins/docker-buildx  /usr/local/libexec/docker/cli-plugins/docker-buildx

# Create and setup Kaniko
RUN <<'EOF'
set -e
mkdir /kaniko
chmod 777 /kaniko
EOF

COPY --from=kaniko      /kaniko/executor                                    /kaniko/executor

# Install kubectl with architecture support
RUN <<'EOF'
set -e
case "$TARGETARCH" in
    amd64) ARCH="amd64" ;;
    arm64) ARCH="arm64" ;;
    *) echo "Error: Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;;
esac
curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" -o /usr/local/bin/kubectl
chmod 755 /usr/local/bin/kubectl
EOF

# Install regctl for registry operations
RUN <<'EOF'
set -e
case "$TARGETARCH" in
    amd64) ARCH="amd64" ;;
    arm64) ARCH="arm64" ;;
    *) echo "Error: Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;;
esac
curl -fsSL "https://github.com/regclient/regclient/releases/latest/download/regctl-linux-${ARCH}" -o /usr/local/bin/regctl
chmod +x /usr/local/bin/regctl
EOF

# Install cosign for image signing
RUN <<'EOF'
set -e
case "$TARGETARCH" in
    amd64) ARCH="amd64" ;;
    arm64) ARCH="arm64" ;;
    *) echo "Error: Unsupported TARGETARCH: $TARGETARCH" >&2; exit 1 ;;
esac
curl -fsSL "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-${ARCH}" -o /usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
EOF

# Copy buildctl-daemonless.sh wrapper script
COPY ./buildctl-daemonless.sh /usr/bin/
RUN chmod 755 /usr/bin/buildctl-daemonless.sh

# Copy cibuild entrypoint script
COPY ./cibuild_entrypoint.sh /usr/local/bin/
RUN chmod 755 /usr/local/bin/cibuild_entrypoint.sh

# Copy CA certificates for local registry trust store
COPY ./localregistry/root.pem   /usr/local/share/ca-certificates/root.pem
COPY ./localregistry/signing.pem /usr/local/share/ca-certificates/signing.pem

RUN update-ca-certificates

# Switch to non-root user for security
USER user

# Download and install cibuild libraries
RUN <<'EOF'
set -e
cd /home/user
curl -fsSL "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}.tar.gz" | \
    tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin"
chmod -R 755 bin
EOF

# Create empty buildkitd configuration directory and touch config file
RUN <<'EOF'
set -e
mkdir -p /home/user/.config/buildkit
touch /home/user/.config/buildkit/buildkitd.toml
EOF

ENTRYPOINT ["cibuild_entrypoint.sh"]