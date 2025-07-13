ARG BASE_IMAGE=alpine
ARG BASE_TAG=latest
ARG HTTP_PROXY=
ARG HTTPS_PROXY=
ARG http_proxy=
ARG https_proxy=

FROM ${BASE_IMAGE}:${BASE_TAG}

USER root

ENV TZ=Europe/Berlin
# hadolint ignore=DL3018
RUN <<EOF
set -e
apk add --no-cache \
tzdata \
curl \
bash \
skopeo \
jq \
git \
iproute2 \
socat
EOF

USER dockremap:dockremap

