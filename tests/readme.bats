#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "README.md exists" {
    [ -f "./README.md" ]
}

@test "README.md has title" {
    run grep "# cibuilder" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md mentions buildkit:rootless" {
    run grep "buildkit:rootless" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md mentions cibuild libs" {
    run grep "cibuild" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md describes check binary" {
    run grep -E "check.*regctl.*jq" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md describes build binary" {
    run grep -E "build.*buildctl" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md describes test binary" {
    run grep -E "test.*kubectl" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md describes release binary" {
    run grep -E "release.*regctl.*cosign" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md mentions CIBUILD_RUN environment variable" {
    run grep "CIBUILD_RUN" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md describes embed cibuild libs" {
    run grep -E "embed.*cibuild" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md mentions external cibuild libs configuration" {
    run grep "Dynamic" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md mentions CIBUILDER_BIN_URL" {
    run grep "CIBUILDER_BIN_URL" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md mentions CIBUILDER_BIN_REF" {
    run grep "CIBUILDER_BIN_REF" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md mentions ca certs for localregistry" {
    run grep "ca certs.*localregistry" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md has GitHub source reference" {
    run grep "github" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README.md mentions GitHub source" {
    run grep "github.com/stack4ops" "./README.md"
    [ "$status" -eq 0 ]
}