#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "cibuild_entrypoint.sh exists and is executable" {
    [ -f "./cibuild_entrypoint.sh" ]
    [ -x "./cibuild_entrypoint.sh" ]
}

@test "cibuild_entrypoint.sh has correct shebang" {
    run head -n 1 "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == "#!/bin/sh" ]]
}

@test "cibuild_entrypoint.sh has set -eu for error handling" {
    run grep "set -eu" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh defines PROJECT_DIR variable" {
    run grep 'PROJECT_DIR.*CI_PROJECT_DIR' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh sets DOCKER_CONFIG" {
    run grep 'DOCKER_CONFIG.*home/user/.docker' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh checks for cibuilder.locked directory" {
    run grep "cibuilder.locked" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh handles CIBUILDER_BIN_URL environment variable" {
    run grep "CIBUILDER_BIN_URL" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh handles CIBUILDER_BIN_REF environment variable" {
    run grep "CIBUILDER_BIN_REF" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh has default values for CIBUILDER_BIN_URL" {
    run grep 'CIBUILDER_BIN_URL.*https://github.com/stack4ops/cibuild/archive/refs/heads' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh has default values for CIBUILDER_BIN_REF" {
    run grep 'CIBUILDER_BIN_REF.*main' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh deletes existing bin directory" {
    run grep -E 'rm -r "bin"' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh downloads and extracts cibuild libs" {
    run grep 'curl.*tar xzf' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh sets chmod for bin directory" {
    run grep 'chmod -R 755.*bin' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh changes directory back to PROJECT_DIR" {
    run grep 'cd.*PROJECT_DIR' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh sets BUILDKITD_FLAGS with default" {
    run grep 'BUILDKITD_FLAGS.*-oci-worker-no-process-sandbox' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh requires CIBUILD_RUN_CMD environment variable" {
    run grep 'CIBUILD_RUN_CMD.*missing' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh has exec_cmd function" {
    run grep "exec_cmd() {" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh handles rootlesskit mode" {
    run grep "CIBUILDER_ROOTLESS_KIT" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh runs cibuild with correct arguments" {
    run grep 'cibuild -r.*CIBUILD_RUN_CMD' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh validates CIBUILD_RUN_CMD values" {
    run grep 'case.*CIBUILD_RUN_CMD' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh supports check command" {
    run grep -E '\bcheck\b' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh supports build command" {
    run grep -E '\bbuild\b' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh supports test command" {
    run grep -E '\btest\b' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh supports release command" {
    run grep -E '\brelease\b' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh supports all command" {
    run grep -E '\ball\b' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh rejects unsupported commands" {
    run grep "unsupported CIBUILD_RUN_CMD" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh exits with code 1 for unsupported commands" {
    run grep 'exit 1' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}