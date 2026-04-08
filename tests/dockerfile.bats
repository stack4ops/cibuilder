#!/usr/bin/env bats

setup() {
    cd "$BATS_TEST_DIRNAME/.."
}

@test "Dockerfile exists" {
    [ -f "./Dockerfile" ]
}

@test "Dockerfile uses correct base image" {
    run grep "FROM.*moby/buildkit:rootless" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile has source label" {
    run grep 'org.opencontainers.image.source="https://github.com/stack4ops/cibuilder"' "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile has description label" {
    run grep 'org.opencontainers.image.description' "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile has licenses label" {
    run grep 'org.opencontainers.image.licenses="Apache-2.0"' "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile defines TARGETARCH build arg" {
    run grep "ARG TARGETARCH" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile defines proxy build args" {
    run grep "ARG HTTP_PROXY=" "./Dockerfile"
    [ "$status" -eq 0 ]
    run grep "ARG HTTPS_PROXY=" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile defines CIBUILDER build args" {
    run grep "ARG CIBUILDER_BIN_URL" "./Dockerfile"
    [ "$status" -eq 0 ]
    run grep "ARG CIBUILDER_BIN_REF" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile installs required packages" {
    run grep "apk add" "./Dockerfile"
    [ "$status" -eq 0 ]
    run grep -E "(jq|bash)" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile copies docker cli from dockercli stage" {
    run grep "COPY --from=dockercli.*docker" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile copies buildx from dockercli stage" {
    run grep "COPY --from=dockercli.*docker-buildx" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile creates kaniko directory" {
    run grep "mkdir /kaniko" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile copies kaniko executor" {
    run grep "COPY --from=kaniko.*executor" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile supports multiple architectures for kubectl" {
    run grep "amd64" "./Dockerfile"
    [ "$status" -eq 0 ]
    run grep "arm64" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile downloads kubectl" {
    run grep "curl.*kubectl" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile downloads regctl" {
    run grep "curl.*regctl" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile downloads cosign" {
    run grep "curl.*cosign" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile copies buildctl-daemonless.sh" {
    run grep "COPY.*buildctl-daemonless.sh" "./Dockerfile"
    [ "$status" -eq 0 ]
    run grep "chmod 755 /usr/bin/buildctl-daemonless.sh" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile copies cibuild_entrypoint.sh" {
    run grep "COPY.*cibuild_entrypoint.sh" "./Dockerfile"
    [ "$status" -eq 0 ]
    run grep "chmod 755 /usr/local/bin/cibuild_entrypoint.sh" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile copies CA certs" {
    run grep "COPY.*localregistry.*root.pem" "./Dockerfile"
    [ "$status" -eq 0 ]
    run grep "COPY.*localregistry.*signing.pem" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile updates CA certificates" {
    run grep "update-ca-certificates" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile sets timezone" {
    run grep "TZ=Europe/Berlin" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile sets PATH correctly" {
    run grep 'ENV PATH=.*home/user/bin' "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile uses USER user" {
    run grep "USER user" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile downloads cibuild libs" {
    run grep 'curl.*CIBUILDER_BIN_URL.*tar.gz' "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile creates buildkit config directory" {
    run grep "/home/user/.config/buildkit" "./Dockerfile"
    [ "$status" -eq 0 ]
}

@test "Dockerfile sets ENTRYPOINT" {
    run grep 'ENTRYPOINT.*cibuild_entrypoint.sh' "./Dockerfile"
    [ "$status" -eq 0 ]
}