#!/bin/bash
# Re-runs interfaces.py and, only if the resulting geo-enrichment actually
# changed (WAN IP renewed by the ISP, or wg0/pia got a new server-assigned
# tunnel IP), recreates the Filebeat container so it picks up the new
# values. Env vars are baked into the container at creation time via
# --env-file -- a plain `podman restart` does NOT reload them, so a full
# recreate (filebeat-raspberrysrv-podman.sh) is required, not just a
# restart. Safe to run frequently: skips the recreate (and the few-second
# Filebeat gap it causes) entirely when nothing changed.
#
# Meant to run on a schedule via refresh-filebeat-enrichment.timer (see
# scripts/refresh-filebeat-enrichment-timer-install.sh), not by hand.
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

hash_enrichment() {
    cat env/localnet.env env/vpnet.env env/piavpn.env 2>/dev/null | sha256sum
}

BEFORE_HASH="$(hash_enrichment)"

# interfaces.py has no error handling of its own -- if an interface is
# briefly down (e.g. mid-reconnect) it throws and exits non-zero. `set -e`
# means this script just exits here too, leaving the container untouched;
# the next scheduled run picks it up once the interface is back.
/usr/bin/python3 scripts/interfaces.py

AFTER_HASH="$(hash_enrichment)"

if [ "$BEFORE_HASH" != "$AFTER_HASH" ]; then
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') IP change detected in localnet/vpnet/piavpn enrichment -- recreating Filebeat"
    ./scripts/filebeat-raspberrysrv-podman.sh
else
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') No IP change, Filebeat left untouched"
fi
