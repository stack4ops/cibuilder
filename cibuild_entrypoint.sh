#!/bin/sh
# cibuild_entrypoint.sh - CI entrypoint for cibuild with dynamic library loading
#
# This script manages the CI build process by:
# - Dynamically loading cibuild libraries from external source
# - Configuring buildkitd flags
# - Executing cibuild commands with optional rootlesskit wrapper

set -eu

PROJECT_DIR="${CI_PROJECT_DIR:-$(pwd)}"
export DOCKER_CONFIG="${DOCKER_CONFIG:-/home/user/.docker}"

# Only load dynamic cibuild libraries if not locked
if [ ! -d "/tmp/cibuilder.locked" ]; then
    if [ -n "${CIBUILDER_BIN_URL:-}" ] || [ -n "${CIBUILDER_BIN_REF:-}" ]; then
        # Default values if not specified
        CIBUILDER_BIN_URL="${CIBUILDER_BIN_URL:-https://github.com/stack4ops/cibuild/archive/refs/heads}"
        CIBUILDER_BIN_REF="${CIBUILDER_BIN_REF:-main}"

        echo "using CIBUILDER_BIN_URL: ${CIBUILDER_BIN_URL}"
        echo "using CIBUILDER_BIN_REF: ${CIBUILDER_BIN_REF}"

        cd /home/user

        # Remove existing bin directory if present
        if [ -d "bin" ]; then
            echo "delete existing /home/user/bin folder"
            rm -r "bin"
        fi

        # Download and extract cibuild libraries with error checking
        echo "downloading cibuild libraries..."
        if ! curl -L -s "${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}.tar.gz" | tar xzf - --strip-components=1 "cibuild-${CIBUILDER_BIN_REF}/bin"; then
            echo >&2 "Error: failed to download cibuild libraries from ${CIBUILDER_BIN_URL}/${CIBUILDER_BIN_REF}.tar.gz"
            exit 1
        fi

        chmod -R 755 "bin"
        echo "cibuild libraries loaded successfully"
    fi
fi

# Return to project directory
cd "${PROJECT_DIR}"

# Set generic default BUILDKITD_FLAGS that works in most environments
export BUILDKITD_FLAGS="${BUILDKITD_FLAGS:--oci-worker-no-process-sandbox}"

# Require CIBUILD_RUN_CMD to be set
: "${CIBUILD_RUN_CMD:?Error: CIBUILD_RUN_CMD environment variable is missing or empty}"

# Execute cibuild with optional rootlesskit wrapper
exec_cmd() {
    if [ "${CIBUILDER_ROOTLESS_KIT:-1}" = "1" ]; then
        echo "running in rootlesskit"
        rootlesskit -- /bin/sh -c "cibuild -r ${CIBUILD_RUN_CMD}"
    else
        echo "running without rootlesskit"
        cibuild -r "${CIBUILD_RUN_CMD}"
    fi
}

# Execute the specified build command
case "${CIBUILD_RUN_CMD}" in
    check|build|test|release|all)
        exec_cmd
        ;;
    *)
        echo >&2 "Error: unsupported CIBUILD_RUN_CMD: '${CIBUILD_RUN_CMD}'"
        echo >&2 "Valid commands: check, build, test, release, all"
        exit 1
        ;;
esac