#!/bin/sh
# Build all cibuilder targets into local Docker image store
#
# Usage: ./build-local.sh [target] [extra docker buildx args...]
#
# Examples:
#   ./build-local.sh                          # build all targets
#   ./build-local.sh release                  # build single target
#   ./build-local.sh release --no-cache       # build single target without cache
#   ./build-local.sh update-caches --no-cache --build-arg FOO=bar

set -e

ALL_TARGETS="base check build-buildctl build-buildx build-nix build-kaniko test-docker test-k8s release update-caches all"

# first arg is a known target or empty → use as target, rest are extra args
# first arg starts with "--" → no target specified, use all targets
if [ -z "${1:-}" ]; then
  TARGETS="${ALL_TARGETS}"
  EXTRA_ARGS=""
elif echo "${ALL_TARGETS}" | grep -qw "${1}"; then
  TARGETS="$1"
  shift
  EXTRA_ARGS="$*"
else
  TARGETS="${ALL_TARGETS}"
  EXTRA_ARGS="$*"
fi

for target in $TARGETS; do
  echo "==> building target: ${target}"
  docker buildx build \
    --build-arg FORCE_DOWNLOAD_CIBUILD=$(date +%s) \
    --target "${target}" \
    --tag "localhost/cibuilder:${target}" \
    --load \
    ${EXTRA_ARGS} \
    .
done

echo ""
echo "==> done"
docker images localhost/cibuilder