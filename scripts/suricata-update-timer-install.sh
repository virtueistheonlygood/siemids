#!/bin/bash
# Installs the daily suricata-update systemd timer on raspberrysrv. Safe to
# re-run. The timer live-reloads Suricata's rules with no capture gap -- see
# resources/suricata/suricata-update.service for how (extra disk-backed swap
# + nice/ionice on the update process, after plain live-reload was found to
# reliably OOM-kill the compile/test step at this deployment's ~78k-rule
# size). Also enables two custom IoC rules (resources/suricata/local-rules/)
# via --local: URLhaus known-malicious domains and Spamhaus DROP-listed
# outbound destinations, refreshed daily by scripts/refresh-ioc-datasets.sh.
set -e

BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Extra disk-backed swap for the suricata-update compile/test step: this
# deployment's rule count needs more headroom than the 2GB zram swap alone
# provides for a second (test) copy of the detection engine to build
# alongside the live one. Without it, the test step reliably OOM-kills
# (confirmed via dmesg); with it, zero OOM kills observed. Idempotent --
# reuses /var/swap if it already exists (stock on some Raspberry Pi OS
# images), creates it otherwise, and persists it via /etc/fstab so it's
# still active after a reboot.
SWAPFILE=/var/swap
if [ ! -f "$SWAPFILE" ]; then
  sudo fallocate -l 2G "$SWAPFILE" || sudo dd if=/dev/zero of="$SWAPFILE" bs=1M count=2048
  sudo chmod 600 "$SWAPFILE"
  sudo mkswap "$SWAPFILE"
fi
sudo swapon "$SWAPFILE" 2>/dev/null || true
grep -qF "$SWAPFILE" /etc/fstab || echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab > /dev/null

# `suricata-update` with zero enabled sources does NOT fall back to ET/Open --
# it only refreshes Suricata's own bundled protocol/anomaly event rules
# (dns-events.rules etc.), which aren't real threat signatures. et/open must
# be enabled explicitly like any other source, or the daily timer silently
# never pulls a real ruleset at all.
sudo suricata-update enable-source et/open

# IoC rulesets: abuse.ch's feeds, all free, CC0-licensed, low false-positive
# rate. feodotracker = active botnet C2 IPs (5 rules), sslbl-blacklist =
# malicious TLS certs (~10.2k rules), sslbl-ja3 = malicious JA3 fingerprints
# (~100 rules) -- all lightweight single-content-match rules, unlike urlhaus
# below. All three alert.signature/rule.name values start with either
# "ET CNC Feodo Tracker" or "SSLBL:", which is what the IoC dashboard panel
# and detection rule (see README) filter on. No ThreatFox here -- abuse.ch
# doesn't publish it as a suricata-update source, only as MISP/CSV/STIX.
#
# Deliberately NOT enabling abuse.ch/sslbl-c2: abuse.ch deprecated this feed
# on 2025-01-03 -- the "ruleset" is just a header comment, zero actual rules.
#
# Deliberately NOT enabling abuse.ch/urlhaus: it's ~30k content-heavy HTTP
# rules -- tested twice (with Suricata both running and stopped), and
# compiling it in needs more memory than this Pi has under any configuration
# tried so far (confirmed via dmesg both times). Only re-enable this on
# hardware with meaningfully more RAM.
sudo suricata-update enable-source abuse.ch/feodotracker
sudo suricata-update enable-source abuse.ch/sslbl-blacklist
sudo suricata-update enable-source abuse.ch/sslbl-ja3

# Etnetera aggressive IP blacklist: free, MIT-licensed, ~16 rules --
# negligible on its own, but even this tiny an addition used to OOM-kill the
# compile/test step before the swap + nice/ionice fix above.
sudo suricata-update enable-source etnetera/aggressive

sudo suricata-update update-sources

# Custom IoC rules (URLhaus known-malicious domains, Spamhaus DROP-listed outbound
# destinations -- see resources/suricata/local-rules/) merged in via --local. Copy the
# rule files into place and populate their data files before the first suricata-update
# run, same as refresh-ioc-datasets.sh does on every subsequent daily run.
sudo mkdir -p /var/lib/suricata/rules.local
sudo cp "$BASE_DIR"/resources/suricata/local-rules/*.rules /var/lib/suricata/rules.local/
sudo "$BASE_DIR/scripts/refresh-ioc-datasets.sh"

# Same nice/ionice live-reload the daily timer uses (see
# resources/suricata/suricata-update.service) -- Suricata is never stopped.
sudo nice -n 19 ionice -c3 suricata-update --local /var/lib/suricata/rules.local

sudo cp "$BASE_DIR/resources/suricata/suricata-update.service" /etc/systemd/system/suricata-update.service
sudo cp "$BASE_DIR/resources/suricata/suricata-update.timer" /etc/systemd/system/suricata-update.timer
sudo systemctl daemon-reload
sudo systemctl enable --now suricata-update.timer

echo "suricata-update.timer installed. Next run:"
systemctl list-timers suricata-update.timer --no-pager
