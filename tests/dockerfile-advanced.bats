#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "Dockerfile has multi-stage build" {
    run grep -E "^FROM" "./Dockerfile"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -ge 3 ]
}

@test "Dockerfile uses as keyword for stage names" {
    run grep -i "\\sas\\s" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile stages use specific names" {
    run grep -E "AS\\s+(dockercli|kaniko)" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile has proper base image selection" {
    run grep "FROM.*buildkit:rootless" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile sets user to root before modifications" {
    run grep "^USER root" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile sets user to user for runtime" {
    run grep "^USER user" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile has LABEL directives" {
    run grep -E "^LABEL" "./Dockerfile"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -ge 3 ]
}

@test "Dockerfile ARG before ENV" {
    run bash -c 'grep -n "^ARG" Dockerfile | head -1'
    run bash -c 'grep -n "^ENV" Dockerfile | head -1'
    [ "$status" -eq 0 ]
}

@test "Dockerfile uses heredoc for RUN" {
    run grep "<<EOF" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile apk add --no-cache" {
    run grep -E "apk add.*--no-cache" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile has security in mind" {
    run grep "set -e" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile installs ca-certificates" {
    run grep "ca-certificates" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile installs openssh" {
    run grep "openssh" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile installs curl" {
    run grep "curl" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile packages include git" {
    run grep "\\bgit\\b" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile copies from stages" {
    run grep "COPY --from" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile creates /kaniko directory with permissions" {
    run grep -A 1 "mkdir /kaniko" "./Dockerfile"
    [[ "$output" =~ "chmod" ]]
}

@test "Dockerfile kubectl download uses case statement" {
    run grep -A 5 'case.*TARGETARCH' "./Dockerfile"
    [[ "$output" =~ "amd64" ]] && [[ "$output" =~ "arm64" ]]
}

@test "Dockerfile handles unsupported architecture" {
    run grep "Unsupported" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile uses https for downloads" {
    run grep "https://" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile sets executable permissions" {
    run grep "chmod.*755\\|chmod.*\\+x" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile copies localregistry certs" {
    run grep "localregistry" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile updates CA trust store" {
    run grep "update-ca-certificates" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile downloads github releases" {
    run grep "github.com.*releases" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile uses latest in release URLs" {
    run grep "releases/latest" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile architecture-specific downloads" {
    run grep -E "amd64|arm64" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile sets timezone environment" {
    run grep "TZ=" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile docker buildx plugin directory" {
    run grep "cli-plugins" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile uses ENV for PATH" {
    run grep "^ENV PATH=" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile rootless user home directory" {
    run grep "/home/user" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile has buildkit config" {
    run grep "buildkit" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile creates config directories" {
    run grep "mkdir.*config" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile ENTRYPOINT is array format" {
    run grep -E "ENTRYPOINT\\s+\\[" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile supports build arguments" {
    run grep "ARG" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile has labeled images" {
    run grep "org.opencontainers" "./Dockerfile"
    [ "$status" -eq 0 ]
}