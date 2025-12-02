FROM docker:cli

ARG HTTP_PROXY=
ARG HTTPS_PROXY=
ARG http_proxy=
ARG https_proxy=

ARG TARGETARCH=amd64

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

# add cibuilder user
RUN <<EOF
addgroup -g 1000 cibuilder
adduser -D -G cibuilder -u 1000 cibuilder
EOF

# add entrypoint
COPY ./cibuild_entrypoint.sh /usr/local/bin/
RUN <<EOF
chmod 755 /usr/local/bin/cibuild_entrypoint.sh
EOF

USER cibuilder

RUN <<EOF
cd /home/cibuilder
curl -L -s "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}/cibuild-${CIBUILDER_BIN_REF}.tar.gz" | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin"
chmod -R 755 bin
EOF

ENV HOME=/home/cibuilder

ENTRYPOINT ["cibuild_entrypoint.sh"]