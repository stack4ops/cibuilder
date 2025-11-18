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

ENV BUILDX_MODE=normal

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

# see https://app.docker.com/accounts/stack4ops/cloud/integrations/gitlab
# this will use a docker-buildx with cloud driver integrated 

# replace buildx located in alpine: /usr/local/libexec/docker/cli-plugins/docker-buildx
# download binary from https://github.com/docker/buildx-desktop/tags

# unfortunatly docker does not provide an official buildx binary with docker cloud driver. 
# This is bundled with docker desktop. The actions-toolkit/main version is behind official buildx releases
# embed switch $BUILDX_MODE 
RUN <<EOF
BUILDX_URL=$(curl -s https://raw.githubusercontent.com/docker/actions-toolkit/main/.github/buildx-lab-releases.json | jq -r ".latest.assets[] | select(endswith(\"linux-$TARGETARCH\"))")
mv /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/bin/buildx
curl --silent -L --output /usr/local/bin/buildx-cloud $BUILDX_URL
chmod a+x /usr/local/bin/buildx*
printf '%s\n' \
'#!/bin/sh' \
'if [ "$BUILDX_MODE" = "cloud" ]; then' \
'  exec /usr/local/bin/buildx-cloud "$@"' \
'else' \
'  exec /usr/local/bin/buildx "$@"' \
'fi' \
> /usr/local/bin/docker-buildx
chmod +x /usr/local/bin/docker-buildx
EOF

# add cibuilder user
RUN <<EOF
addgroup -g 1000 cibuilder
adduser -D -G cibuilder -u 1000 cibuilder
EOF

USER cibuilder
ENV HOME=/home/cibuilder
