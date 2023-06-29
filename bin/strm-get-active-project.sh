#!/bin/bash
email=$(strm auth show | grep -oE '\[[^]]+\]' | tr -d '[]')
echo "$email"

p=${STRM_CONFIG_PATH:-$HOME/.config/strmprivacy}
active_projects=$(<$p/active_projects.json)

active_project=$(cat $p/active_projects.json | jq -r '.users[] | select(.email == "'"$email"'") | .active_project')
strm list projects  -o json | jq --arg n "$active_project" -r '.projects[] | select(.name == $n)'
