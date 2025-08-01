ARG BASE_IMAGE=alpine
ARG BASE_TAG=latest
ARG HTTP_PROXY=
ARG HTTPS_PROXY=
ARG http_proxy=
ARG https_proxy=

ARG SKOPEO_VERSION=1.18.0
ARG TARGETARCH=amd64

FROM ${BASE_IMAGE}:${BASE_TAG}

ARG SKOPEO_VERSION
ARG TARGETARCH

USER root

ENV TZ=Europe/Berlin
# hadolint ignore=DL3018
RUN <<EOF
set -e
apk add --no-cache \
tzdata \
curl \
bash \
jq \
git \
iproute2 \
socat
EOF

# Mapping TARGETARCH -> skopeo release suffix
RUN case "$TARGETARCH" in \
        amd64) ARCH=amd64 ;; \
        arm64) ARCH=arm64 ;; \
    *) echo "Unsupported arch: $TARGETARCH" && exit 1 ;; \
    esac && \
    curl -L -o /usr/local/bin/skopeo \
      "https://github.com/containers/skopeo/releases/download/v${SKOPEO_VERSION}/skopeo-static-linux-${ARCH}" && \
    chmod +x /usr/local/bin/skopeo

USER dockremap:dockremap
