#!/bin/sh

ret=$(docker run --rm $docker_run_options --name $test_container_name $test_image docker buildx version | grep "github.com/docker/buildx")

if [ "$?" != "0" ] || [ -z "$ret" ] ; then
  log 0 "Test failed!"
  exit 1
fi

log 1 "detected buildx version in dockerx image: $ret"
