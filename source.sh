#!/bin/bash

# Source this file to be able to use the utilities in this repo.
# Descriptions of the utilities are available in the README.

old_path="$PWD"
trap 'cd "$old_path"' ERR

# https://stackoverflow.com/a/246128/5889131
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1

__utilities_dir="$PWD"

# random utilities
. "$__utilities_dir/utils.sh"

# gitlab registry api
gitlabcontainerregistryapi() {
  "$__utilities_dir/gitlabcontainerregistryapi.sh" "$@"
}
alias glregistry="gitlabcontainerregistryapi"

# docker utilities
. "$__utilities_dir/docker.sh"

# pd
. "$__utilities_dir/pd.sh"

trap - ERR
cd "$old_path"
