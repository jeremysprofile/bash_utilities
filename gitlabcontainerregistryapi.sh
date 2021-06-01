#!/bin/bash
# HOWTO: make the script executable (`chmod +x registryapi`); then just run it (`./registryapi`) for help.

# requirements: `jq` (`brew install jq`)
#               edit gitlab_token and container_registry_group_ids to match your needs.

# Set gitlab_token to be your private API token (or use these variables and hope your setup is identical to mine
# and that you have ripgrep installed)
mvnrc="$HOME/.m2/settings.xml"
gitlab_token=$(rg $mvnrc -Noe '<value>(.*)</value>' -r '$1')

# Set the group ids to be all the group IDs you will ever look at containers for.
# For instance, I care about TradeGuard and DCASS.
container_registry_group_ids=("1364" "661")


if [[ "$__enterprise" == "nasdaq" ]]; then
  __fqdn="git.nasdaq.com"
else
  __fqdn="gitlab.com"
fi

# You shouldn't need to edit anything past here unless there's a bug.

# see API docs:
# https://docs.gitlab.com/ee/api/container_registry.html
# https://docs.gitlab.com/ee/api/README.html#pagination defaults to 20

for id in "${container_registry_group_ids[@]}"; do
  files+=("/tmp/gitlab_group_$id.json")
done
json_file="/tmp/gitlab_groups.json"


update_outdated_repo_data() {
  local updated=""
  for i in "${!files[@]}"; do
    local file="${files[$i]}"
    if [[ ! -f "$file" ]]; then
       update_repo_data "$i"
       updated='yes'
    # elif modification timestamp is older than 15 min ago
    elif (( $(date -r "$file" +%s) <= $(date +%s) - 60*15 )); then
       update_repo_data "$i"
       updated='yes'
    fi
  done
  if [[ "$updated" ]]; then
    cat "${files[@]}" | jq -n '[inputs] | add' > "$json_file"
  fi
}

update_repo_data() {
  local file="${files[$1]}"
  local id="${container_registry_group_ids[$1]}"
  curl -Ssl --header "PRIVATE-TOKEN: $gitlab_token" "https://$__fqdn/api/v4/groups/$id/registry/repositories?per_page=100" > "$file"
}

get_repo_data() {
  update_outdated_repo_data
  cat "$json_file"
}

get_all_tags() {
  local project_id="$1"
  local repo_id="$2"

  curl -Ssl --header "PRIVATE-TOKEN: $gitlab_token" \
    "https://$__fqdn/api/v4/projects/$project_id/registry/repositories/$repo_id/tags?per_page=100" \
    | jq -r '.[].name'
  curl -Ssl --header "PRIVATE-TOKEN: $gitlab_token" \
    "https://$__fqdn/api/v4/projects/$project_id/registry/repositories/$repo_id/tags?per_page=100&page=2" \
    | jq -r '.[].name'
}


tag_data() {
  if (( $# > 2 || $# == 0 )); then
    echo "takes 1 or 2 arguments:"
    echo '$1: the (partial) *path* of the project in either TG or DCASS.'
    echo 'If $1 matches more than one project, it will display all matches.'
    echo 'If $1 has one match, it will display all tags for that container.'
    echo '$2: the tag name. Optional.'
    echo 'If $2 is not provided, it will output all tags for that container.'
    echo 'If $2 is not an exact match for a tag name, it will display all partial matches.'
    echo 'If $2 is an exact match for a tag name, it will display the metadata for that tag.'
    return 1
  fi
  local partial_path="$1"
  local tag_name="$2"

  local json=$(get_repo_data)
  local filtered_repo_data=$(echo "$json" | jq --arg name "$partial_path" '.[] | select (.location|test($name))')

  local matches=($(echo "$filtered_repo_data" | jq '.id'))
  if (( ${#matches[@]} != 1 )); then
    echo "Exactly 1 match for '$1' not found. Please use a unique substring of one of the 'path' values below:"
    echo "Found:"
    echo "$filtered_repo_data" | jq '{ id: .id, name: .name, path: .path, project_id: .project_id }'
    return 1
  fi

  local project_id=$(jq '.project_id' <<< "$filtered_repo_data")
  local repo_id=$(jq '.id' <<< "$filtered_repo_data")

  if [[ "$tag_name" ]]; then
    local tags=$(curl -Ssl --header "PRIVATE-TOKEN: $gitlab_token" \
      "https://$__fqdn/api/v4/projects/$project_id/registry/repositories/$repo_id/tags/$tag_name")
    if echo $tags | grep '404 Tag Not Found' -q; then
      # 404'd
      get_all_tags $project_id $repo_id | grep "$tag_name" | column -x
    else
      echo $tags | jq .
    fi
  else
    get_all_tags $project_id $repo_id | column -x
  fi
}

tag_data "$@"
