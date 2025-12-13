FROM docker:cli

ARG HTTP_PROXY=
ARG HTTPS_PROXY=
ARG http_proxy=
ARG https_proxy=

ARG TARGETARCH

ARG CIBUILDER_BIN_URL=https://gitlab.com/stack4ops/public/cibuild/-/archive
ARG CIBUILDER_BIN_REF=main

USER root

ENV TZ=Europe/Berlin

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/cibuilder/bin

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

# add buildkit
RUN <<EOF
set -e
BUILDKIT_VERSION=$(curl -s https://api.github.com/repos/moby/buildkit/releases/latest | jq -r .tag_name)
case "$TARGETARCH" in \
    amd64) ARCH="amd64" ;; \
    arm64) ARCH="arm64" ;; \
    *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;;
esac
curl -L "https://github.com/moby/buildkit/releases/download/${BUILDKIT_VERSION}/buildkit-${BUILDKIT_VERSION}.linux-${ARCH}.tar.gz" | tar -xz bin/buildctl -C /usr/local/bin --strip-components=1
ls -lat /usr/local/bin
chmod +x /usr/local/bin/buildctl
EOF

# add kubectl
RUN <<EOF
set -e
case "$TARGETARCH" in \
    amd64) ARCH="amd64" ;; \
    arm64) ARCH="arm64" ;; \
    *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;;
esac
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl"
chmod 755 kubectl 
mv kubectl /usr/local/bin
EOF

# add cibuilder user
RUN <<EOF
set -e
addgroup -g 1000 cibuilder
adduser -D -G cibuilder -u 1000 cibuilder
EOF

# add entrypoint
COPY ./cibuild_entrypoint.sh /usr/local/bin/
RUN <<EOF
set -e
chmod 755 /usr/local/bin/cibuild_entrypoint.sh
EOF

USER cibuilder

RUN <<EOF
set -e
cd /home/cibuilder
curl -L -s "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}/cibuild-${CIBUILDER_BIN_REF}.tar.gz" | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin"
chmod -R 755 bin
EOF

ENV HOME=/home/cibuilder

ENTRYPOINT ["cibuild_entrypoint.sh"]