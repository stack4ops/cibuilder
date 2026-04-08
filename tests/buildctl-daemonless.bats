#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "buildctl-daemonless.sh exists and is executable" {
    [ -f "./buildctl-daemonless.sh" ]
    [ -x "./buildctl-daemonless.sh" ]
}

@test "buildctl-daemonless.sh has correct shebang" {
    run head -n 1 "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == "#!/bin/sh" ]]
}

@test "buildctl-daemonless.sh has set -eu for error handling" {
    run grep "set -eu" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh defines all required variables" {
    run grep "BUILDCTL=buildctl" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]

    run grep "BUILDKITD=buildkitd" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]

    run grep "BUILDKITD_FLAGS=" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]

    run grep "ROOTLESSKIT=rootlesskit" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh has cleanup function" {
    run grep "cleanup() {" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]

    run grep "trap" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh creates temp directory" {
    run grep "mktemp -d /tmp/buildctl-daemonless" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh has startBuildkitd function" {
    run grep "startBuildkitd() {" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh has waitForBuildkitd function" {
    run grep "waitForBuildkitd() {" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh handles rootlesskit correctly" {
    run grep "ROOTLESSKIT_STATE_DIR" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh handles real root case" {
    run grep 'id -u' "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh has retry logic" {
    run grep "BUILDCTL_CONNECT_RETRIES_MAX" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh executes buildctl with correct args" {
    run grep '\$BUILDCTL.*\$@' "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}