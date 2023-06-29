#!/bin/bash
active_user_email=$(strm auth show | grep -oE '\[[^]]+\]' | tr -d '[]')
p=${STRM_CONFIG_PATH:-$HOME/.config/strmprivacy}
active_project=$(cat $p/active_projects.json | jq -r '.users[] | select(.email == "'"$active_user_email"'") | .active_project')
strm list projects  -o json | jq --arg n "$active_project" -r '.projects[] | select(.name == $n)'
