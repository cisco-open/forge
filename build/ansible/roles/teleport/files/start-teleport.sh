#!/bin/bash

source /etc/userdata

cmd="/usr/local/bin/teleport start --diag-addr=0.0.0.0:3000 --pid-file=/run/teleport.pid"

INSTANCE_ID=$(wget -q -O - http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.instanceId')
TENANT=$(wget -q -O - http://169.254.169.254/latest/meta-data/tags/instance/TeleportTenantName)

sed -e "s|\$TENANT|$TENANT|g" \
    -e "s|\$INSTANCE_ID|$INSTANCE_ID|g" \
    /etc/teleport.yaml.tpl >/etc/teleport.yaml

exec $cmd
