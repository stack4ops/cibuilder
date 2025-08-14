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
iproute2 \
socat \
skopeo
EOF

# see https://app.docker.com/accounts/stack4ops/cloud/integrations/gitlab
# this will use a docker-buildx with cloud driver integrated 

# overwrite usage of default buildx located in alpine: /usr/local/libexec/docker/cli-plugins/docker-buildx
# download binary from https://github.com/docker/buildx-desktop/tags and use in /home/dockremap/.docker/cli-plugins/docker-buildx

RUN <<EOF
BUILDX_URL=$(curl -s https://raw.githubusercontent.com/docker/actions-toolkit/main/.github/buildx-lab-releases.json | jq -r ".latest.assets[] | select(endswith(\"linux-$TARGETARCH\"))")
mkdir -vp /home/dockremap/.docker/cli-plugins/
curl --silent -L --output /home/dockremap/.docker/cli-plugins/docker-buildx $BUILDX_URL
chown -R dockremap:dockremap /home/dockremap/.docker
chmod a+x /home/dockremap/.docker/cli-plugins/docker-buildx
EOF

USER dockremap:dockremap
