ARG BASE_IMAGE=alpine
ARG BASE_TAG=latest
ARG HTTP_PROXY=
ARG HTTPS_PROXY=
ARG http_proxy=
ARG https_proxy=

FROM ${BASE_IMAGE}:${BASE_TAG}

ARG TARGETARCH=amd64

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
skopeo
EOF

# add cibuilder user
RUN <<EOF
addgroup -g 1000 cibuilder
adduser -D -G cibuilder -u 1000 cibuilder
EOF

USER cibuilder
ENV HOME=/home/cibuilder
