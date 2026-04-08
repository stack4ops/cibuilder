#!/bin/sh
# buildctl-daemonless.sh spawns ephemeral buildkitd for executing buildctl.
#
# Usage: buildctl-daemonless.sh build ...
#
# Flags for buildkitd can be specified as $BUILDKITD_FLAGS
#
# The script is compatible with BusyBox shell.

# Exit on error and undefined variables
set -eu

# Default values with safe parameter expansion
: "${BUILDCTL:=buildctl}"
: "${BUILDCTL_CONNECT_RETRIES_MAX:=10}"
: "${BUILDKITD:=buildkitd}"
: "${BUILDKITD_FLAGS:=}"
: "${ROOTLESSKIT:=rootlesskit}"
: "${XDG_RUNTIME_DIR:=/tmp}"

# Cleanup function to remove temporary files and kill background processes
cleanup() {
    if [ -f "${tmp}/pid" ]; then
        pid=$(cat "${tmp}/pid")
        kill "${pid}" 2>/dev/null || true
    fi
    rm -rf "${tmp}" 2>/dev/null || true
}

# Create temporary directory structure
# $tmp holds the following files:
# * pid - buildkitd process ID
# * addr - buildkitd socket address
# * log - buildkitd log output
tmp=$(mktemp -d "${XDG_RUNTIME_DIR}/buildctl-daemonless.XXXXXX")
trap cleanup EXIT

# Start buildkitd with appropriate socket address
startBuildkitd() {
    addr="unix://${XDG_RUNTIME_DIR}/buildkit/buildkitd.sock"
    helper=""

    # Determine if we should use rootlesskit based on execution context
    if [ -n "${ROOTLESSKIT_STATE_DIR:-}" ]; then
        # Already running inside rootlesskit
        printf '%s\n' "already inside rootlesskit - never start it again"
    elif [ "$(id -u)" = "0" ]; then
        # Running as real root - use system socket location
        printf '%s\n' "real root: set default socket"
        addr="unix:///run/buildkit/buildkitd.sock"
    else
        # Running as non-root user - use rootlesskit helper
        printf '%s\n' "use rootlesskit helper"
        helper="${ROOTLESSKIT}"
    fi

    # Start buildkitd in background with logging
    ${helper} ${BUILDKITD} ${BUILDKITD_FLAGS} --addr="${addr}" >"${tmp}/log" 2>&1 &
    pid=$!
    echo "${pid}" >"${tmp}/pid"
    echo "${addr}" >"${tmp}/addr"
}

# Wait for buildkitd to become ready
# buildkitd supports NOTIFY_SOCKET but there's no easy way to wait for
# NOTIFY_SOCKET activation using busybox-builtin commands, so we poll instead
waitForBuildkitd() {
    addr=$(cat "${tmp}/addr")
    try=0
    max=${BUILDCTL_CONNECT_RETRIES_MAX}

    until ${BUILDCTL} --addr="${addr}" debug workers >/dev/null 2>&1; do
        if [ "${try}" -gt "${max}" ]; then
            echo >&2 "Error: could not connect to ${addr} after ${max} trials"
            echo >&2 "========== buildkitd log =========="
            cat >&2 "${tmp}/log"
            exit 1
        fi
        # Exponential backoff: start at 100ms, increase by 20ms each try
        sleep $(awk "BEGIN{print (100 + ${try} * 20) * 0.001}")
        try=$(expr "${try}" + 1)
    done
}

# Main execution
startBuildkitd
waitForBuildkitd
${BUILDCTL} --addr="$(cat "${tmp}/addr")" "$@"