#!/bin/sh
# Build all cibuilder targets into local Docker image store
# Usage: ./build-local.sh [target]
#   target: optional, build only this target
#   e.g.:   ./build-local.sh base
#           ./build-local.sh release

set -e

TARGETS="base check build-buildctl build-buildx build-nix build-kaniko test-docker test-k8s release update-caches all"

if [ -n "${1:-}" ]; then
  TARGETS="$1"
fi

for target in $TARGETS; do
  echo "==> building target: ${target}"
  docker buildx build \
    --build-arg FORCE_DOWNLOAD_CIBUILD=$(date +%s) \
    --target "${target}" \
    --tag "localhost/cibuilder:${target}" \
    --load \
    .
done

echo ""
echo "==> done"
docker images localhost/cibuilder