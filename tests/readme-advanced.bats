#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "README has proper markdown heading" {
    run grep -E "^#" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions customizations" {
    run grep -i "custom" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README documents binaries" {
    run grep -E "(binary|tool)" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README lists check tools" {
    run grep -i "check" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README lists build tools" {
    run grep -i "build" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README lists test tools" {
    run grep -i "test" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README lists release tools" {
    run grep -i "release" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions regctl" {
    run grep "regctl" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions jq" {
    run grep "\\bjq\\b" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions docker-cli" {
    run grep "docker-cli" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions buildx" {
    run grep "buildx" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions cosign" {
    run grep "cosign" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions kubectl" {
    run grep "kubectl" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README has link to cibuild" {
    run grep -E "(github|cibuild)" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README sections are marked with dashes" {
    run grep "^---" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README uses bullet points" {
    run grep "^\\*\\|\\-\\s" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README has notes section" {
    run grep -i "note" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions update cycle" {
    run grep -i "(update|cycle|week)" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions cache" {
    run grep -i "cache" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README describes base image" {
    run grep "buildkit" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions gitlab pipeline" {
    run grep -i "gitlab" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README describes custom entrypoint" {
    run grep "entrypoint" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions executable binaries" {
    run grep -E "(executable|\\*\\s+\\*\\w+\\*\\:)" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README uses markdown code formatting" {
    run grep -E '`[^`]`' "./README.md"
    [ "$status" -eq 0 ]
}

@test "README has proper indentation" {
    run grep "^\\s\\s\\s\\s\\*" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions embedded libs" {
    run grep "embed" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions localregistry" {
    run grep "localregistry" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README mentions certificates" {
    run grep -i "cert" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README has descriptive title" {
    run grep -B 1 "An image" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README structure is logical" {
    run wc -l "./README.md"
    [ "$status" -eq 0 ]
    [ "$output" -gt 10 ]
}

@test "README uses consistent formatting" {
    run grep "^\\*" "./README.md"
    [ "$status" -eq 0 ]
    count=$(echo "$output" | wc -l)
    [ "$count" -gt 5 ]
}

@test "README mentions rootless" {
    run grep "rootless" "./README.md"
    [ "$status" -eq 0 ]
}

@test "README has version information" {
    run grep -i "(version|ref)" "./README.md"
    [ "$status" -eq 0 ]
}