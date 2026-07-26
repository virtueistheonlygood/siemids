#!/bin/bash
# Installs the WAN/VPN IP-change watcher timer on raspberrysrv. Safe to
# re-run. Every 5 minutes (see resources/filebeat/refresh-filebeat-enrichment.timer),
# checks whether the WAN public IP, wg0's tunnel IP, or pia's tunnel IP has
# changed since the last check, and only recreates the Filebeat container
# (a real, if brief, capture gap) when one actually has -- see
# scripts/refresh-filebeat-enrichment.sh for why a recreate is needed
# instead of a plain restart.
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

sudo cp "$BASE_DIR/resources/filebeat/refresh-filebeat-enrichment.service" /etc/systemd/system/refresh-filebeat-enrichment.service
sudo cp "$BASE_DIR/resources/filebeat/refresh-filebeat-enrichment.timer" /etc/systemd/system/refresh-filebeat-enrichment.timer
sudo systemctl daemon-reload
sudo systemctl enable --now refresh-filebeat-enrichment.timer

echo "refresh-filebeat-enrichment.timer installed. Next run:"
systemctl list-timers refresh-filebeat-enrichment.timer --no-pager
