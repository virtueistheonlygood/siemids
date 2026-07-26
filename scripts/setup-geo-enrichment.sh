#!/bin/bash
# One-time (idempotent) setup for server-side Suricata geo-enrichment: creates
# the net-geo-source index, the two Enrich policies (net-geo-cidr,
# net-geo-profile), seeds it with current interface data, executes both
# policies, and patches filebeat-8.17.4-suricata-eve-pipeline to use them.
# Replaces Filebeat's client-side add_fields geo processors (see
# resources/filebeat/filebeat-raspberrysrv.yml git history) -- run this once,
# on the ELK host or anywhere with network access to it, before relying on
# refresh-filebeat-enrichment.sh to keep the enrichment data current.
#
# Prerequisites: env/elk.env and certs/ca/ca.crt already present (same as
# filebeat-raspberrysrv-podman.sh's own prerequisites), and this script run
# from a checkout that also has scripts/interfaces.py's own prerequisites
# (i.e. run it on raspberrysrv, not skynetpi -- it needs eth0/wg0/pia).
#
# Safe to re-run: index/policy creation steps are skipped if they already
# exist. NOTE: Elasticsearch does not support updating an existing enrich
# policy's definition or an existing index's field types in place -- if
# resources/elasticsearch/enrich-policies.json or net-geo-mapping.json
# change later, delete the affected policy (`DELETE _enrich/policy/<name>`)
# and/or index first, then re-run this script.
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$BASE_DIR"

ELASTICSEARCH_HOSTS="$(grep -m1 '^ELASTICSEARCH_HOSTS=' env/elk.env | cut -d= -f2-)"
ELASTICSEARCH_PASSWORD="$(grep -m1 '^ELASTICSEARCH_PASSWORD=' env/elk.env | cut -d= -f2-)"
CURL="curl -sS --cacert $BASE_DIR/certs/ca/ca.crt -u elastic:${ELASTICSEARCH_PASSWORD}"

echo "1. Creating net-geo-source index..."
if $CURL -o /dev/null -w '%{http_code}' "${ELASTICSEARCH_HOSTS}/net-geo-source" | grep -q '^200$'; then
    echo "   already exists, skipping."
else
    $CURL -X PUT "${ELASTICSEARCH_HOSTS}/net-geo-source" \
        -H "Content-Type: application/json" \
        -d @resources/elasticsearch/net-geo-mapping.json
fi

echo "2. Creating enrich policies..."
for policy in net-geo-cidr net-geo-profile; do
    if $CURL -o /dev/null -w '%{http_code}' "${ELASTICSEARCH_HOSTS}/_enrich/policy/${policy}" | grep -q '^200$'; then
        echo "   ${policy} already exists, skipping."
    else
        body="$(python3 -c "import json; print(json.dumps(json.load(open('resources/elasticsearch/enrich-policies.json'))['${policy}']))")"
        $CURL -X PUT "${ELASTICSEARCH_HOSTS}/_enrich/policy/${policy}" \
            -H "Content-Type: application/json" -d "$body"
    fi
done

echo "3. Seeding net-geo-source with current interface data (interfaces.py)..."
python3 scripts/interfaces.py

echo "4. Executing both enrich policies..."
for policy in net-geo-cidr net-geo-profile; do
    $CURL -X POST "${ELASTICSEARCH_HOSTS}/_enrich/policy/${policy}/_execute"
done

echo "5. Applying the patched Suricata eve pipeline..."
$CURL -X PUT "${ELASTICSEARCH_HOSTS}/_ingest/pipeline/filebeat-8.17.4-suricata-eve-pipeline" \
    -H "Content-Type: application/json" \
    -d @resources/elasticsearch/suricata-eve-pipeline-patch.json

echo "Done."
