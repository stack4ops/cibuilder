#!/bin/sh

set -eu

# only dynamic cibuild loading libs if not locked (p.e production gitlab-runner) 
if [ ! -d "/tmp/cibuilder.locked" ]; then
    if [ -n "${CIBUILDER_BIN_URL:-}" ] || [ -n "${CIBUILDER_BIN_REF:-}" ]; then
        CIBUILDER_BIN_URL="${CIBUILDER_BIN_URL:-https://gitlab.com/stack4ops/public/cibuild/-/archive}"
        CIBUILDER_BIN_REF="${CIBUILDER_BIN_REF:-main}"

        echo "using CIBUILDER_BIN_URL: ${CIBUILDER_BIN_URL}"
        echo "using CIBUILDER_BIN_REF: ${CIBUILDER_BIN_REF}"

        cd /home/user

        if [ -d "bin" ]; then
            echo "delete existing /home/user/bin folder"
            rm -r "bin"
        fi

        curl -L -s "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}/cibuild-${CIBUILDER_BIN_REF}.tar.gz" | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/"
        chmod -R 755 "bin"
    fi
fi

# set generic default BUILDKITD_FLAGS working mostly everywhere
export BUILDKITD_FLAGS="${BUILDKITD_FLAGS:--oci-worker-no-process-sandbox}"

: "${CIBUILDER_STAGE:?missing CIBUILDER_STAGE}"

case "$CIBUILDER_STAGE" in
  check)  cibuild -s check ;;
  build)  cibuild -s build ;;
  test)   cibuild -s test ;;
  deploy) cibuild -s deploy ;;
  main)   cibuild -s main ;;
  *)
    echo "unsupported CIBUILDER_STAGE: $CIBUILDER_STAGE"
    exit 1
    ;;
esac
