#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "cibuild_entrypoint.sh has proper shebang and shell" {
    run grep -E "^#!/.*sh" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh uses error handling" {
    run grep "set -" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "e" ]] || [[ "$output" =~ "u" ]]
}

@test "cibuild_entrypoint PROJECT_DIR has fallback" {
    run grep 'PROJECT_DIR.*CI_PROJECT_DIR.*pwd' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh uses parameter expansion correctly" {
    run grep '${' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh handles missing bin directory" {
    run grep -E "if.*bin|\\[.*bin" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh downloads with curl in silent mode" {
    run grep "curl.*-s" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh extracts tar.gz correctly" {
    run grep "tar.*xzf" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh uses strip-components" {
    run grep "strip-components" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh extracts correct cibuild directory" {
    run grep -E "cibuild-\\$\\{.*bin" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh changes to home directory" {
    run grep "/home/user" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh returns to project dir" {
    run grep '\$PROJECT_DIR' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh BUILDKITD_FLAGS has default value" {
    run grep 'BUILDKITD_FLAGS.*:-' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh exports environment variables" {
    run grep "^export" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh validates CIBUILD_RUN_CMD" {
    run grep 'CIBUILD_RUN_CMD' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh has error for missing CIBUILD_RUN_CMD" {
    run grep "missing" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh uses exec for final command" {
    run grep "^exec" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh supports check|build|test|release|all" {
    run grep -E '(check|build|test|release|all)' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh handles unknown command" {
    run grep -E '\*|default|unsupported' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh exec_cmd uses rootlesskit" {
    run grep "rootlesskit" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh shows mode message" {
    run grep "echo" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh handles locked directory" {
    run grep "locked" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh locked description mentions markdown" {
    run grep "/tmp/cibuilder.locked" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh uses colon null check" {
    run grep '^:' "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh has proper case statement" {
    run grep 'case' "./cibuild_entrypoint.sh" | grep -q 'esac'
    [ "$status" -eq 0 ]
}

@test "cibuild_entrypoint.sh runs cibuild with -r flag" {
    run grep "cibuild.*-r" "./cibuild_entrypoint.sh"
    [ "$status" -eq 0 ]
}