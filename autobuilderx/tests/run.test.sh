#!/bin/sh

# edit your test conditions
if ! docker_run_output=$(docker run --rm $docker_run_options --entrypoint /usr/bin/uname --name "${test_container_name:?}" "${test_image:?}" -a); then
  log 3 "Test failed: Container did not start successfully!"
  docker logs -t "${test_container_name}"
  exit 1
fi

echo "$docker_run_output"

log 5 "Test successfull: Container did start"
