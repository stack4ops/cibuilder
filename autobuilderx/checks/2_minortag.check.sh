if [ "${pipeline_env}" = "local" ] && [ "${local_only}" = "1" ]; then
  log 5 "skip minortag.check in local_only mode"
  return 18
fi

tls_verify=''
if [ "${insecure_tls:?}" = "1" ]; then
    tls_verify="--tls-verify=false"
fi

creds=""

if [ -n "${base_registry_user:-}" ] && [ -n "${base_registry_pass:-}" ]; then
  creds="--creds ${base_registry_user}:${base_registry_pass}"
fi

get_minor_tag() {
  log 7 "start: get_minor_tag"

  if [ ! -n "${minor_tag_regex:-}" ]; then
    log 4 "no minor tag regex defined. skipping check_minor_tag"
    return 0
  fi
  
  if ! repository_tags=$(skopeo inspect "${tls_verify}" $creds "docker://$base_image:$base_tag"); then
    log 3 "something went wrong while inspecting the image docker://$base_image:$base_tag"
    return 1
  fi

  log 5 "minor_tag_regex: ${minor_tag_regex}"
  
  current_digest=$(skopeo inspect "${tls_verify}" $creds --no-tags --format '{{ .Layers }}' docker://${base_image}:${base_tag} | tr -d '"' | tr -d '[:space:]')

  log 5 "current_digest: ${current_digest}"

  if ! minor_tags=$(echo "$repository_tags" | jq --arg minor_tag_regex_arg "${minor_tag_regex}" '.RepoTags | reverse | .[] | select(. | test($minor_tag_regex_arg))'); then
    log 3 "something went wrong while parsing the minor tags from the inspected json result"
    return 1
  fi
  for minor_tag in $minor_tags; do
    mt=$(echo $minor_tag | tr -d '"')
    if ! minor_tag_digest=$(skopeo inspect "${tls_verify}" $creds --no-tags --format '{{ .Layers }}' docker://${base_image}:$mt | tr -d '"' | tr -d '[:space:]'); then
      log 3 "something went wrong while getting the minor_tag_digest for docker://${base_image}:$mt"
    fi
    log 5 "$minor_tag_digest - $mt"
    if [ "$minor_tag_digest" = "$current_digest" ]; then
      log 5 "found matching tag for $base_tag = $mt with same digest $current_digest"
      set_cache_entry "cache_minor_tag" "$mt"
      log 5 "cache_minor_tag: ${cache_minor_tag}"
      return 18
      break
    fi
  done
  if [ -z "$mt" ]; then
    log 3 "could not get minor_tag from $base_tag"
    return 1
  fi
}

get_minor_tag