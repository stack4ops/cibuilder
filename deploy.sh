#!/bin/sh
# Deploy all cibuilder targets to ghcr.io
# Usage: ./deploy.sh [target]
#   target: optional, deploy only this target
#   e.g.:   ./deploy.sh base
#           ./deploy.sh release

set -e

TARGETS="base check build-buildctl build-buildx build-nix build-kaniko test-docker test-k8s release update all"

if [ -n "${1:-}" ]; then
  TARGETS="$1"
fi

for target in $TARGETS; do
  echo "==> deploy target: ${target}"
  docker image tag localhost/cibuilder:${target} ghcr.io/stack4ops/cibuilder:${target}
  docker push ghcr.io/stack4ops/cibuilder:${target}
done
