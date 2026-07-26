#!/bin/bash

if ! command -v podman >/dev/null 2>&1; then
    echo "Podman is not installed, please review README.md."
    exit 1
fi
CONTAINER_TOOL="podman"

# Only clean genuinely disposable resources (dangling images, build cache) here.
# This used to also run `volume prune -f` and unconditionally remove the
# elastic_password/kibana_password secrets on every start.sh invocation --
# `system prune -f` removes stopped containers, which then made the ES/Kibana
# named volumes "dangling" and wiped them on the very next line: a full
# from-scratch redeploy (fresh security bootstrap, new random credentials) on
# every restart, including routine reboot recovery. See DEPLOYMENT.md.
sudo $CONTAINER_TOOL system prune -f
