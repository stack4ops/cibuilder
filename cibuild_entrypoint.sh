#!/bin/sh

set -eu

if [ -n "${CIBUILDER_BIN_URL:-}" ] || [ -n "${CIBUILDER_BIN_REF:-}" ]; then
    CIBUILDER_BIN_URL="${CIBUILDER_BIN_URL:-https://gitlab.com/stack4ops/public/cibuild/-/archive}"
    CIBUILDER_BIN_REF="${CIBUILDER_BIN_REF:-main}"

    echo "using CIBUILDER_BIN_URL: ${CIBUILDER_BIN_URL}"
    echo "using CIBUILDER_BIN_REF: ${CIBUILDER_BIN_REF}"

    cd /home/cibuilder

    if [ -d "bin" ]; then
        echo "delete existing /home/cibuilder/bin folder"
        rm -r "bin"
    fi

    curl -L -s "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}/cibuild-${CIBUILDER_BIN_REF}.tar.gz" | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/"
    chmod -R 755 "bin"
fi

exec "$@"