#!/bin/sh

assert_log "github.com/docker/buildx" "/bin/sh" "-c" "docker buildx version; sleep infinity"
