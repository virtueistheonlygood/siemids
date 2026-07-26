#!/bin/bash
# Refreshes the two custom IoC data files consumed by
# resources/suricata/local-rules/{urlhaus-domains,spamhaus-drop-outbound}.rules:
#   - /var/lib/suricata/rules.local/urlhaus-domains.dat (base64-encoded domain list,
#     for the `dataset type string` domain rule)
#   - /var/lib/suricata/rules.local/iprep/{categories.txt,reputation.list} (for the
#     `iprep` outbound-CIDR rule)
#
# Meant to run as part of suricata-update.service's existing stop -> update -> start
# cycle (see ExecStartPre there), not on its own -- these files are only read when
# Suricata (re)loads its rules, so refreshing them separately would do nothing until
# the next rule reload/restart anyway.
#
# Fails loudly and leaves existing files untouched on any fetch/parse problem, rather
# than risking silently replacing a good IoC list with an empty/garbage one -- a stale
# list is safe (same protection as before), a truncated one is not.
set -e

DATA_DIR="/var/lib/suricata/rules.local"
IPREP_DIR="${DATA_DIR}/iprep"
mkdir -p "$DATA_DIR" "$IPREP_DIR"

TMP_URLHAUS="$(mktemp)"
TMP_SPAMHAUS="$(mktemp)"
trap 'rm -f "$TMP_URLHAUS" "$TMP_SPAMHAUS"' EXIT

# --- URLhaus domain list -> base64-encoded dataset file -----------------------------
curl -sS --fail --max-time 30 https://urlhaus.abuse.ch/downloads/hostfile/ \
    | grep -oP '^127\.0\.0\.1\s+\K\S+' \
    | while read -r domain; do printf '%s' "$domain" | base64; done \
    > "$TMP_URLHAUS"

URLHAUS_COUNT="$(wc -l < "$TMP_URLHAUS")"
if [ "$URLHAUS_COUNT" -lt 50 ]; then
    echo "refresh-ioc-datasets: URLhaus fetch returned only $URLHAUS_COUNT domains (expected ~350) -- leaving existing urlhaus-domains.dat untouched" >&2
    exit 1
fi
mv "$TMP_URLHAUS" "${DATA_DIR}/urlhaus-domains.dat"
echo "refresh-ioc-datasets: wrote $URLHAUS_COUNT domains to ${DATA_DIR}/urlhaus-domains.dat"

# --- Spamhaus DROP -> iprep reputation list ------------------------------------------
# EDROP was merged into DROP as of abuse.ch/Spamhaus's own notice (confirmed live,
# 2026-07-26) -- only drop.txt is needed now.
curl -sS --fail --max-time 30 https://www.spamhaus.org/drop/drop.txt \
    | grep -oP '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}' \
    | awk '{print $0",1,127"}' \
    > "$TMP_SPAMHAUS"

SPAMHAUS_COUNT="$(wc -l < "$TMP_SPAMHAUS")"
if [ "$SPAMHAUS_COUNT" -lt 500 ]; then
    echo "refresh-ioc-datasets: Spamhaus DROP fetch returned only $SPAMHAUS_COUNT entries (expected ~1600) -- leaving existing reputation.list untouched" >&2
    exit 1
fi
mv "$TMP_SPAMHAUS" "${IPREP_DIR}/reputation.list"
echo "1,SpamhausDROP" > "${IPREP_DIR}/categories.txt"
echo "refresh-ioc-datasets: wrote $SPAMHAUS_COUNT CIDR entries to ${IPREP_DIR}/reputation.list"
