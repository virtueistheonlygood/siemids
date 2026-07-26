#!/bin/bash
# Re-runs interfaces.py and, only if the resulting geo data actually changed
# (WAN IP renewed by the ISP, or wg0/pia got a new server-assigned tunnel
# IP), re-executes the two net-geo-* Elasticsearch enrich policies so the
# ingest-pipeline-side enrichment (see resources/elasticsearch/,
# scripts/setup-geo-enrichment.sh) picks up the new values. Filebeat itself
# is never touched by this script -- geo enrichment moved server-side
# specifically to remove the need to recreate it for routine IP changes
# (see DEPLOYMENT.md). Safe to run frequently: skips the policy
# re-execution entirely when nothing changed.
#
# Meant to run on a schedule via refresh-filebeat-enrichment.timer (see
# scripts/refresh-filebeat-enrichment-timer-install.sh), not by hand.
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

hash_enrichment() {
    cat geoip/localnet.json geoip/vpnet.json geoip/piavpn.json 2>/dev/null | sha256sum
}

BEFORE_HASH="$(hash_enrichment)"

# interfaces.py has no error handling of its own -- if an interface is
# briefly down (e.g. mid-reconnect) it throws and exits non-zero. `set -e`
# means this script just exits here too; the next scheduled run picks it up
# once the interface is back. Nothing has been pushed to Elasticsearch yet
# at that point (interfaces.py pushes as its last step, after all three
# lookups succeed).
/usr/bin/python3 scripts/interfaces.py

AFTER_HASH="$(hash_enrichment)"

if [ "$BEFORE_HASH" != "$AFTER_HASH" ]; then
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') IP change detected in localnet/vpnet/piavpn enrichment -- re-executing enrich policies"
    ELASTICSEARCH_HOSTS="$(grep -m1 '^ELASTICSEARCH_HOSTS=' env/elk.env | cut -d= -f2-)"
    ELASTICSEARCH_PASSWORD="$(grep -m1 '^ELASTICSEARCH_PASSWORD=' env/elk.env | cut -d= -f2-)"
    for policy in net-geo-cidr net-geo-profile; do
        curl -sS --cacert certs/ca/ca.crt -u "elastic:${ELASTICSEARCH_PASSWORD}" \
            -X POST "${ELASTICSEARCH_HOSTS}/_enrich/policy/${policy}/_execute"
    done
else
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') No IP change, enrich policies left untouched"
fi
