#!/bin/bash
p=${STRM_CONFIG_PATH:-$HOME/.config/strmprivacy}
default_project_name=$(<$p/active_project)

strm list projects  -o json | jq --arg n "$default_project_name" -r '.projects[] | select(.name == $n)'
