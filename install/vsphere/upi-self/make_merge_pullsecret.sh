#!/usr/bin/bash

jq -c --argjson var "$(jq .auths $HOME/pullsecret_config.json)" '.auths += $var' $HOME/ocp_pullsecret.json > $HOME/merged_pullsecret.json