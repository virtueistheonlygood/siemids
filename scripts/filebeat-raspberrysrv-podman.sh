#!/bin/bash
# Deploys/redeploys this Pi's Filebeat instance via plain podman (this host
# has no podman-compose). Ships Suricata's eve.json, this host's own
# auditd/syslog/auth.log, and AdGuard Home's query log to the central
# Elasticsearch host over HTTPS/mTLS. Safe to re-run: replaces any existing
# container of the same name.
#
# One-time prerequisites before running this:
#   1. Run ./start.sh on the ELK host at least once, so certs/ and the
#      elastic_password secret exist.
#   2. Copy certs/ca/ca.crt and certs/filebeat/{filebeat.crt,filebeat.key}
#      from the ELK host into $BASE_DIR/certs/{ca,filebeat}/ on this Pi.
#   3. Run scripts/interfaces.py on this Pi to generate env/localnet.env,
#      env/vpnet.env and env/piavpn.env (needed by the geo-enrichment
#      processors).
#   4. Install and enable auditd + rsyslog on this Pi (it runs journald-only
#      by default, so /var/log/audit/audit.log, /var/log/syslog and
#      /var/log/auth.log don't exist otherwise): `apt install auditd rsyslog`.
#   5. Create env/elk.env with ELASTICSEARCH_HOSTS/ELASTICSEARCH_PASSWORD (see Usage
#      below) so this script can be re-run unattended.
#
# Usage:
#   ./filebeat-raspberrysrv-podman.sh
#   (reads ELASTICSEARCH_HOSTS/ELASTICSEARCH_PASSWORD from env/elk.env -- see below.
#   Both can still be overridden by passing them as explicit env vars instead, e.g. for
#   a one-off run against a different ELK host.)
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CERTS_DIR="$BASE_DIR/certs"

# env/elk.env holds ELASTICSEARCH_HOSTS/ELASTICSEARCH_PASSWORD as plain KEY=value lines
# (create it once: printf 'ELASTICSEARCH_HOSTS=https://<elk-host-ip>:9200\nELASTICSEARCH_PASSWORD=<elastic_password>\n' > env/elk.env).
# This lets the script be re-run unattended without retyping the ELK password every
# time. Only used as a fallback -- an explicit env var passed to the script still wins.
# This directory on raspberrysrv is a plain scp'd copy, not a git checkout, so there's
# no risk of the real password ending up committed.
if [ -f "$BASE_DIR/env/elk.env" ]; then
    ELASTICSEARCH_HOSTS="${ELASTICSEARCH_HOSTS:-$(grep -m1 '^ELASTICSEARCH_HOSTS=' "$BASE_DIR/env/elk.env" | cut -d= -f2-)}"
    ELASTICSEARCH_PASSWORD="${ELASTICSEARCH_PASSWORD:-$(grep -m1 '^ELASTICSEARCH_PASSWORD=' "$BASE_DIR/env/elk.env" | cut -d= -f2-)}"
fi

CONTAINER_NAME="filebeat"
STACK_VERSION="${STACK_VERSION:-8.17.4}"
ELASTICSEARCH_HOSTS="${ELASTICSEARCH_HOSTS:?Set ELASTICSEARCH_HOSTS, e.g. https://192.168.100.3:9200 (or create env/elk.env)}"
ELASTICSEARCH_PASSWORD="${ELASTICSEARCH_PASSWORD:?Set ELASTICSEARCH_PASSWORD, copied from the elastic_password secret on the ELK host (or create env/elk.env)}"

if [ ! -f "$CERTS_DIR/ca/ca.crt" ] || [ ! -f "$CERTS_DIR/filebeat/filebeat.crt" ]; then
    echo "Missing certs under $CERTS_DIR -- copy ca/ca.crt and filebeat/{filebeat.crt,filebeat.key} from the ELK host's certs/ first."
    exit 1
fi

if [ ! -f "$BASE_DIR/env/localnet.env" ] || [ ! -f "$BASE_DIR/env/vpnet.env" ] || [ ! -f "$BASE_DIR/env/piavpn.env" ]; then
    echo "Missing $BASE_DIR/env/*.env -- run scripts/interfaces.py on this Pi first."
    exit 1
fi

# Filebeat refuses to start unless its config file is owned by root and not
# group/world-writable.
sudo chown root:root "$BASE_DIR/resources/filebeat/filebeat-raspberrysrv.yml" "$BASE_DIR/resources/suricata/suricata.yml"
sudo chmod go-w "$BASE_DIR/resources/filebeat/filebeat-raspberrysrv.yml" "$BASE_DIR/resources/suricata/suricata.yml"

sudo podman rm -f "$CONTAINER_NAME" 2>/dev/null || true

sudo podman run -d \
    --name "$CONTAINER_NAME" \
    --user root \
    --hostname raspberrysrv \
    --env-file "$BASE_DIR/env/localnet.env" \
    --env-file "$BASE_DIR/env/vpnet.env" \
    --env-file "$BASE_DIR/env/piavpn.env" \
    -e ELASTICSEARCH_HOSTS="$ELASTICSEARCH_HOSTS" \
    -e ELASTICSEARCH_USERNAME=elastic \
    -e ELASTICSEARCH_PASSWORD="$ELASTICSEARCH_PASSWORD" \
    -v "$BASE_DIR/resources/filebeat/filebeat-raspberrysrv.yml:/usr/share/filebeat/filebeat.yml:ro" \
    -v "$BASE_DIR/resources/suricata/suricata.yml:/usr/share/filebeat/modules.d/suricata.yml:ro" \
    -v "$BASE_DIR/env/localnet.env:/usr/share/filebeat/localnet.env:ro" \
    -v "$BASE_DIR/env/vpnet.env:/usr/share/filebeat/vpnet.env:ro" \
    -v "$BASE_DIR/env/piavpn.env:/usr/share/filebeat/piavpn.env:ro" \
    -v "$CERTS_DIR:/usr/share/elasticsearch/config/certs:ro" \
    -v /suricata/:/suricata/:ro \
    -v /var/log/:/var/log/:ro \
    -v /home/skynet/adguardhome/work/data:/adguard:ro \
    --restart=always \
    docker.elastic.co/beats/filebeat:"$STACK_VERSION" \
    filebeat --environment container -c /usr/share/filebeat/filebeat.yml

echo "Filebeat deployed, shipping /suricata/eve.json to $ELASTICSEARCH_HOSTS"
