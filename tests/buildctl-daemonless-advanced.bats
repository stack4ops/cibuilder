#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "buildctl-daemonless.sh uses BusyBox compatible sh" {
    run grep -E "#!(/bin/sh|/usr/bin/sh)" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh has proper error propagation" {
    run grep "set -eu" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh cleanup handles gracefully" {
    run grep -A 5 "cleanup()" "./buildctl-daemonless.sh"
    [[ "$output" =~ "kill" ]] || [[ "$output" =~ "rm -rf" ]]
}

@test "buildctl-daemonless.sh uses mktemp for temp directory" {
    run grep "mktemp" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh temp directory pattern" {
    run grep "/tmp/buildctl-daemonless" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh creates pid file" {
    run grep -E "pid.*>.*tmp/pid" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh creates addr file" {
    run grep -E "addr.*>.*tmp/addr" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh creates log file" {
    run grep "tmp/log" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh has correct trap setup" {
    run grep -E "trap.*cleanup" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh rootlesskit check updates helper variable" {
    run grep -A 5 "ROOTLESSKIT_STATE_DIR" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh handles root user correctly" {
    run grep -E "id.*0|root" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh sets buildkitd socket correctly for root" {
    run grep "/run/buildkit/buildkitd.sock" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh sets buildkitd socket correctly for rootless" {
    run grep "XDG_RUNTIME_DIR" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh waitForBuildkitd has retry loop" {
    run grep -A 10 "waitForBuildkitd" "./buildctl-daemonless.sh"
    [[ "$output" =~ "until" ]] && [[ "$output" =~ "do" ]]
}

@test "buildctl-daemonless.sh implements exponential backoff" {
    run grep -A 5 "sleep" "./buildctl-daemonless.sh"
    [[ "$output" =~ "try" ]] || [[ "$output" =~ "expr" ]]
}

@test "buildctl-daemonless.sh has error message on connection failure" {
    run grep "could not connect" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh displays log on failure" {
    run grep -E "log.*>" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
    run grep "cat.*log" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh passes arguments to buildctl" {
    run grep -E '\$@|\$\*' "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh uses XDG_RUNTIME_DIR" {
    run grep "XDG_RUNTIME_DIR" "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh has configurable BUILDKITD_FLAGS" {
    run grep -E '\$BUILDKITD_FLAGS|\$\{BUILDKITD_FLAGS' "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh background process with &" {
    run grep -E '.*&$' "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}

@test "buildctl-daemonless.sh uses $! for pid capture" {
    run grep '\$!' "./buildctl-daemonless.sh"
    [ "$status" -eq 0 ]
}