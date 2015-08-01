#!/bin/bash

set -e
set -u

DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


(
  cat "${DIR}/base.json" | jq -c '.'
  
  for LOG_FORMAT in cloudtrail s3 ; do
    sed "s/{{LogFormat}}/${LOG_FORMAT}/g" "${DIR}/resource.json.tmpl"
  done
) \
  | jq --slurp '.[0] + { "Resources": ( .[1:] | add ) }' \
  > "${DIR}/../cloudformation.json"
