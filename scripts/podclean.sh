#!/bin/sh
# Truncate log files for containers using the k8s-file log driver.
# On systemd hosts Podman defaults to the journald driver instead, where
# log volume is managed by journald rotation (see `journalctl --vacuum-size`).
sudo sh -c '
for logpath in $(podman ps -aq | xargs -r podman inspect --format "{{.LogPath}}" 2>/dev/null); do
  [ -f "$logpath" ] && truncate -s 0 "$logpath"
done
'
