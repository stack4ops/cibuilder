#!/usr/bin/env bash
set -e

# start rootless dockerd
dockerd-entrypoint.sh &

# Warten bis Docker Socket existiert
DOCKER_SOCKET="/run/user/1000/docker.sock"
export DOCKER_HOST="unix://${DOCKER_SOCKET}"
export DOCKER_DRIVER="overlay2"
export DOCKER_TLS_CERTDIR=

echo "waiting for Docker Socket..."
while [ ! -S "$DOCKER_SOCKET" ]; do
    sleep 1
done

echo "Docker Socket active"

docker info

# init buildx
#if ! docker buildx ls | grep -q mybuilder; then
#    docker buildx create --name mybuilder --use
#fi

# Wrapper: übergebe alle Argumente
exec "$@"
