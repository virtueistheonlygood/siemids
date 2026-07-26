#!/bin/bash

# Check if Podman is installed
if ! command -v podman >/dev/null 2>&1
then
    echo "Podman is not installed, please review README.md."
    exit 1
fi
CONTAINER_TOOL="podman"

# Set system parameters, required for Elasticsearch
sudo sysctl -w vm.max_map_count=262144

# Change directory
cd ./scripts

# Change ownership and permissions
sudo chown root:root ../resources/*beat/*.yml ../resources/suricata/suricata*
sudo chmod go-w ../resources/*beat/*.yml

# Only clean genuinely disposable resources here. This used to also run
# `volume prune -f`, which removes any volume not attached to a running
# container -- during crash/retry cycles (containers stopped, not yet
# recreated) this wiped the ES/Kibana data volumes on the very next
# start.sh run. Same bug already fixed once in prune.sh; see DEPLOYMENT.md.
sudo $CONTAINER_TOOL system prune -f
