#!/bin/sh

# only check in scheduled pipelines not commits or other triggers
if [ "${pipeline_env}" = "ci" ] && [ "${CI_PIPELINE_SOURCE:-}" != "schedule" ]; then
  log 2 "base.check only in schedule ci pipeline or local"
  return 18
fi

# layers of base_image check in local_only mode is not possible 
# because layers are not preserved in docker storage
if [ "${local_only}" = "1" ]; then
  log 2 "skip base.check in local_only mode"
  return 18
fi

rand=$RANDOM
layers_base_image_cache="${cache_folder:-/tmp}/base_image_layers_${rand}.json"
layers_target_image_cache="${cache_folder:-/tmp}/target_image_layers_${rand}.json"
layers_intersection="${cache_folder:-/tmp}/layers_intersection_${rand}.json"

tls_verify=''
if [ "${insecure_tls:?}" = "1" ]; then
    tls_verify="--tls-verify=false"
fi

clean_up() {
  if [ -f "${layers_base_image_cache}" ]; then
    rm "${layers_base_image_cache}"
  fi
  if [ -f "${layers_target_image_cache}" ]; then
    rm "${layers_target_image_cache}"
  fi
  if [ -f "${layers_intersection}" ]; then
    rm "${layers_intersection}"
  fi
}

if [ -n "${base_registry_user:-}" ] && [ -n "${base_registry_pass:-}" ]; then
  ret=$(skopeo inspect --creds "${base_registry_user}:${base_registry_pass}" $tls_verify "docker://${base_image:?}:${base_tag:?}")
else
  ret=$(skopeo inspect "docker://${base_image:?}:${base_tag:?}")
fi

status=$?

log 2 "status: $status"

if [ "$status" -gt 0 ]; then
  log 0 "cannot get base image ${base_image}:${base_tag}. Abort"
  clean_up
  return 1
fi

echo $ret | jq '.Layers' >"${layers_base_image_cache}"

if [ -n "${target_registry_user:-}" ] && [ -n "${target_registry_pass:-}" ]; then
  ret=$(skopeo inspect --creds "${target_registry_user}:${target_registry_pass}" $tls_verify "docker://${target_image:?}:${target_tag:?}")
else
  ret=$(skopeo inspect "docker://${target_image:?}:${target_tag:?}")
fi

status=$?

log 2 "status: $status"

if [ "$status" -gt 0 ]; then
  log 1 "cannot get last target image ${target_image}:${target_tag}. Assume this is the first bild"
  clean_up
  return 18
fi

echo $ret | jq '.Layers' >"${layers_target_image_cache}"

# get the intersection of the two lists
jq -s '.[0] - (.[0] - .[1])' "${layers_target_image_cache}" "${layers_base_image_cache}" >"${layers_intersection}"

if [ "${ci_build_loglevel}" = "3" ]; then
  log 3 "intersection of image layers"
  cat "$layers_intersection"
fi

# check if the intersection matches the base_image
difference_base_image_layers=$(jq -s '.[0] - .[1] | length' "${layers_base_image_cache}" "${layers_intersection}")

if [ "${ci_build_loglevel}" = "3" ]; then
  log 2 "Difference between intersection and base_imaeg layers"
  jq -s '.[0] - .[1]' "${layers_base_image_cache}" "${layers_intersection}"
fi

if [ "$difference_base_image_layers" -gt 0 ]; then
  log 2 "found a difference in the base image layers, build new image"
  clean_up
  return 18
else
  log 2 "found no difference in base image layers, cancel pipeline gracefully"
  clean_up
  if [ "${build_force}" = "1" ]; then
    return 42
  else
    return 43
  fi
fi
