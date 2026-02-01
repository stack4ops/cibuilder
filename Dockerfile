FROM docker:cli AS dockercli
FROM moby/buildkit:rootless

ARG HTTP_PROXY=
ARG HTTPS_PROXY=
ARG http_proxy=
ARG https_proxy=

ARG TARGETARCH

ARG CIBUILDER_BIN_URL=https://gitlab.com/stack4ops/public/cibuild/-/archive
ARG CIBUILDER_BIN_REF=main

USER root

ENV TZ=Europe/Berlin

ENV PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/home/user/bin

RUN <<EOF
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

COPY --from=dockercli   /usr/local/bin/docker  /usr/local/bin/docker
COPY --from=dockercli  /usr/local/libexec/docker/cli-plugins/docker-buildx /usr/local/libexec/docker/cli-plugins/docker-buildx

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

# add regctl
RUN <<EOF
set -e
case "$TARGETARCH" in \
    amd64) ARCH="amd64" ;; \
    arm64) ARCH="arm64" ;; \
    *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;;
esac
echo 1
curl -L https://github.com/regclient/regclient/releases/latest/download/regctl-linux-${ARCH} >/usr/local/bin/regctl
chmod +x /usr/local/bin/regctl
EOF

# add cosign
RUN <<EOF
set -e
case "$TARGETARCH" in \
    amd64) ARCH="amd64" ;; \
    arm64) ARCH="arm64" ;; \
    *) echo "Unsupported TARGETARCH: $TARGETARCH"; exit 1 ;;
esac
curl -L https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-${ARCH} >/usr/local/bin/cosign
chmod +x /usr/local/bin/cosign
EOF

# add entrypoint
COPY ./cibuild_entrypoint.sh /usr/local/bin/
RUN <<EOF
set -e
chmod 755 /usr/local/bin/cibuild_entrypoint.sh
EOF

# add ca certs for localregistry
COPY ./localregistry/root.pem /usr/local/share/ca-certificates/root.pem
COPY ./localregistry/signing.pem /usr/local/share/ca-certificates/signing.pem

RUN <<EOF
update-ca-certificates
EOF

# user context
USER user

RUN <<EOF
set -e
cd /home/user
curl -L -s "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}/cibuild-${CIBUILDER_BIN_REF}.tar.gz" | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin"
chmod -R 755 bin
EOF

# Add empty buildkitd.toml 
RUN <<EOF
mkdir -p /home/user/.config/buildkit
touch /home/user/.config/buildkit/buildkitd.toml
EOF

ENTRYPOINT ["cibuild_entrypoint.sh"]