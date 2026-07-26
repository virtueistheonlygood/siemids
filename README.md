# Open Source 👁 SIEM-IDS Solution

**SIEM-IDS integrates open source tools to monitor, analyze, correlate, and alert on network traffic, systems, applications, and security events in real-time.** It combines Suricata's rule-/signature-based Intrusion Detection (IDS) with the Elastic Stack's centralized log aggregation, real-time correlation, and historical analysis -- giving actionable visibility into your network's privacy and security posture.

> *Disclaimer: This is currently in development and is safe to run in a staging environment or as a demo. However, it is not recommended for production use due to incomplete features, such as partial integration with the OTX API | Threat Intelligence feature.*

## OpenSource Components

### [Suricata](https://github.com/OISF/suricata) | [Elasticsearch](https://github.com/elastic/elasticsearch) | [Kibana](https://github.com/elastic/kibana) | [Filebeat](https://github.com/elastic/beats/tree/main/filebeat) | [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome) | [OTX API](https://otx.alienvault.com/)

- **Suricata**: a Network Intrusion Detection/Prevention System (IDS/IPS) and Network Security Monitoring (NSM) engine -- captures and inspects network traffic, logging alerts as EVE JSON.
- **Filebeat**: ships Suricata's EVE logs to Elasticsearch, which enriches them server-side (see [Geo-IP Enrichment for Private-Network Traffic](#geo-ip-enrichment-for-private-network-traffic)). It also collects and forwards *auditd*, *auth.log*, *syslog*, and [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)'s DNS query log -- the local DNS server this project actually uses.
- **Elasticsearch**: stores and indexes every event Filebeat ships, powering correlation and historical search.
- **Kibana**: the dashboards, saved visualizations, and Detection Engine (detection rules/alerting) built on top of Elasticsearch -- see [Detection Rules](#detection-rules) and [Screenshots](#screenshots).
- **AdGuard Home**: the DNS server/ad-blocker actually run in this deployment; its query log is one of Filebeat's inputs and powers the [DNS Queries](#screenshots) dashboard.
- **OTX API** *(under development)*: optional AlienVault threat-intel IP lookups via a small local Flask API -- see [OTX Open Threat Exchange](#otx-open-threat-exchange-under-development).

## Index

1. [OpenSource Components](#opensource-components)
2. [Architecture](#architecture) (two devices: ELK host + Suricata sensor)
3. [Setup Instructions](#setup-instructions) (clone the repo, install Podman)
4. [Configure Suricata](#configure-suricata)
5. [Getting started](#getting-started) (Device A: the ELK host)
   - [Podman Compose Configuration](#podman-compose-configuration)
   - [Podman Container Security](#podman-container-security)
   - [ELK Configuration and Objects](#elk-configuration-and-objects)
   - [Detection Rules](#detection-rules)
   - [ELK Passwords and Secrets](#elk-passwords-and-secrets)
   - [Filebeat Log Collection and Enrichment](#filebeat-log-collection-and-enrichment)
6. [Ready to start](#ready-to-start) (Device A)
7. [Device B: Suricata Sensor (e.g. a Raspberry Pi router)](#device-b-suricata-sensor-eg-a-raspberry-pi-router)
   - [Geo-IP Enrichment for Private-Network Traffic](#geo-ip-enrichment-for-private-network-traffic)
8. [Traffic Flow Map](#traffic-flow-map)
9. [OTX Open Threat Exchange (under development)](#otx-open-threat-exchange-under-development)
10. [Screenshots](#screenshots)
11. [Contributing](#contributing)
12. [License](#license)

## Architecture

![Architecture diagram](resources/images/architecture-diagram.png)

**This project deploys across two devices**: **Device A** runs the full ELK stack
(Elasticsearch, Kibana, Filebeat) via `podman-compose` -- it needs real RAM for
Elasticsearch. **Device B** runs Suricata natively (a router/AP-class box, e.g. a
Raspberry Pi, is enough) and ships its logs to Device A over the LAN. There's no
supported single-device (everything-on-one-host) setup -- Elasticsearch and Suricata
on the same box is more than most small hardware can handle, and it isn't what this
project is tested against.

The steps below (through [Ready to start](#ready-to-start)) set up **Device A first**
-- its TLS certs need to exist before Device B can connect -- then jump to
[Device B: Suricata Sensor](#device-b-suricata-sensor-eg-a-raspberry-pi-router) to
bring up the second device.

## Setup Instructions

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/virtueistheonlygood/siemids
   cd siemids
   cp .env.example .env
   ```
   `.env` is git-ignored -- `start.sh` writes real, randomly-generated passwords and
   Kibana's encryption key into it on first run, so it must never be committed. Only
   `.env.example` (a secret-free template) is tracked.

2. **Install Podman and podman-compose**:
   - Follow the installation instructions on the [Podman website](https://podman.io/getting-started/installation) and the [podman-compose GitHub repository](https://github.com/containers/podman-compose).

## Configure Suricata

**This project runs Suricata natively, not as a container, and always on Device B** (the sensor) -- see [Device B: Suricata Sensor](#device-b-suricata-sensor-eg-a-raspberry-pi-router) for the full deployment steps; this section covers the config file itself. Install it per the [Suricata documentation](https://suricata.readthedocs.io/en/latest/install.html), then tailor the config to your topology -- start from the stock sample `resources/suricata/suricata.yaml`, or `resources/suricata/suricata-raspberrysrv.yaml` for a fully populated, real-world multi-interface example.

Key configuration aspects include:

1. **Network Interfaces**: Specify the network interfaces that Suricata should monitor for traffic analysis. `threads: auto` resolves to "number of cores" *per interface* -- on a small, multi-purpose box (router/AP also running DNS, VPN, NAT), that can quickly oversubscribe the CPU with several interfaces defined; consider hardcoding a low, deliberate thread count per interface instead, as done here:

  ```yaml
  af-packet:
    - interface: wlan0
      threads: 1
      cluster-id: 99
      cluster-type: cluster_flow
      defrag: yes
      use-mmap: yes
      mmap-locked: yes
      tpacket-v3: yes
      ring-size: 2048
      block-size: 32768
      block-timeout: 10
      use-emergency-flush: yes
      buffer-size: 32768
      disable-promisc: no
      checksum-checks: kernel

    - interface: wg0
      threads: 1
      cluster-id: 98
      cluster-type: cluster_flow
      defrag: yes
      use-mmap: yes
      mmap-locked: yes
      tpacket-v3: yes
      ring-size: 2048
      block-size: 32768
      block-timeout: 10
      use-emergency-flush: yes
      buffer-size: 32768
      disable-promisc: no
      checksum-checks: kernel

    # Values used for any interface not explicitly listed above.
    - interface: default
  ```

2. **Rule Sets**: Specify the rule sets that Suricata should use to detect threats.

  ```yaml
  default-rule-path: /usr/local/var/lib/suricata/rules

  rule-files:
    - suricata.rules
  ```

3. **Logging**: Configure logging options to capture and store alerts and other relevant data. This is the path Filebeat collects Suricata EVE logs from.

  ```yaml
  default-log-dir: /suricata/
  ```

## Getting started

### Podman Compose Configuration

The `podman-compose.yaml` file orchestrates the deployment of the various services needed. It specifies the configuration for each service, including security, network settings, environment variables, and volume mounts, ensuring a seamless integration of all components.

### Podman Container Security

Communication between the containerized services (Elasticsearch, Filebeat, and Kibana) is secured using HTTPS/SSL, with a PKI generated on first run by the `setup_pki` service.
  ```yaml
  setup_pki:
    image: docker.elastic.co/elasticsearch/elasticsearch:${STACK_VERSION}
    volumes:
      - ./certs:/usr/share/elasticsearch/config/certs
    user: "0"
  ```
  - **The certificates used for securing communication between containerized services are stored under the `certs/` directory**.
  - The `elasticsearch` cert's SAN list includes `ELK_LAN_IP` (set in `.env`, defaults to this host's LAN IP) in addition to `elasticsearch`/`localhost`/`127.0.0.1`, so remote Beats agents (e.g. the [Device B: Suricata Sensor](#device-b-suricata-sensor-eg-a-raspberry-pi-router)) connecting by LAN IP get full TLS hostname verification instead of failing on IP mismatch. This only takes effect on first cert generation -- if certs already exist and `ELK_LAN_IP` changes, delete `certs/` and rerun `./start.sh`.

### ELK Configuration and Objects

The visualizations and dashboards are stored in `saved.objects/siemids.ndjson` and
**imported automatically** as part of `./start.sh`/`podman-compose up -d` -- no manual
step needed. This is done by a dedicated one-shot service, `setup_kibana`, which:

1. Waits for the `kibana` service's healthcheck (`depends_on: kibana: condition:
   service_healthy`) before starting at all.
2. Polls `https://localhost:5601` in a loop until it gets back `HTTP/1.1 302 Found`
   (Kibana's redirect-to-login, meaning the HTTP server itself is actually accepting
   requests, not just that the container process is running).
3. `POST`s `saved.objects/siemids.ndjson` to Kibana's `/api/saved_objects/_import`
   endpoint (`compatibilityMode=true` lets objects exported from a slightly different
   Kibana version still import cleanly), authenticating as `elastic` via `ELASTIC_PASSWORD`.
4. Exits. Being `restart: on-failure` rather than `restart: always`, it only reruns if
   step 2/3 actually failed -- a normal successful import doesn't loop or reimport on
   every subsequent `start.sh` run.

  (see the `setup_kibana` service in `podman-compose.yaml` for the exact commands)

- **Configuration files are located in `resources/` directory**

The `[Logs Suricata] Alert Overview` dashboard includes a `Top IoC Feed Matches`
panel (backed by the `IoC Feed Alerts [Logs Suricata]` saved search) that isolates
hits matching the curated IoC feeds specifically -- filtering on
`rule.name: SSLBL* or rule.name: "ET CNC Feodo Tracker*" or rule.name: "ETN AGGRESSIVE*"`
-- broken down by which indicator fired and which host triggered it, separate from the
general "Top Alert Signatures" table where these would otherwise be buried among
thousands of ET/Open matches. The dedicated `siemids-suricata-ioc-feed-match` detection
rule (see [Detection Rules](#detection-rules)) uses the same filter. See
[Device B: Suricata Sensor](#device-b-suricata-sensor-eg-a-raspberry-pi-router) for how
those feeds get enabled.

Two further custom IoC rules cover ground the feeds above don't: **domain-based**
matching (`resources/suricata/local-rules/urlhaus-domains.rules`, abuse.ch URLhaus's
lightweight plaintext domain list via Suricata's `dataset` feature -- deliberately not
the full URLhaus ruleset, which is ~30k content-heavy rules and OOM-kills a Raspberry Pi
4B) and **outbound** IP/CIDR-range matching (`resources/suricata/local-rules/spamhaus-drop-outbound.rules`,
Spamhaus's DROP list via Suricata's `iprep` feature -- `et/open` already covers this same
list *inbound*, so this rule specifically closes the outbound direction: a local device
reaching out to a known-hijacked netblock). Both refreshed daily by
`scripts/refresh-ioc-datasets.sh`, folded into the existing `suricata-update.service`
cycle. See `DEPLOYMENT.md`'s 2026-07-26 entry for the exact `dataset`/`iprep` format
gotchas found along the way (`type string` needs base64-encoded entries; `type ip` does
not accept CIDR ranges, `iprep` does).

### Detection Rules

`saved.objects/detection-rules.ndjson` ships 28 curated detection rules, split between
14 adapted from [Elastic's free prebuilt rule catalog](https://www.elastic.co/guide/en/security/current/prebuilt-rules.html)
(`elastic-*` rule IDs) and 14 authored specifically for this project's actual log
sources and observed noise patterns (`siemids-*` rule IDs) -- every rule is mapped to
its [MITRE ATT&CK](https://attack.mitre.org/) tactic/technique.

| Category | Rules |
| --- | --- |
| **SSH / Credential Access** | Brute-force (internal/external/successful, both a custom threshold rule and Elastic's EQL variants), direct root login, first-seen source IP, unusual user or SSH public key |
| **Privilege escalation / `sudo` misuse** | `sudo` spawning an interactive shell (`sudo bash`/`su`), `sudo` touching `/etc/passwd`, `/etc/shadow`, `/etc/sudoers`, or account-management commands |
| **Persistence / account & system changes** | New Linux user/group creation, manual `nftables` firewall changes (excluding netavark's and wg-quick's own automatic table churn), suspicious `rc.local` errors |
| **Kernel integrity** | Tainted or out-of-tree kernel module loads, executable-stack process starts, suspicious `bpf_probe_write_user` usage |
| **Command and control** | AdGuard blocked-query spike from one client (beaconing indicator), Cobalt Strike's default team-server TLS certificate, **Suricata IoC feed match** (`siemids-suricata-ioc-feed-match` -- fires specifically on Feodo Tracker/SSLBL indicator hits, high severity, separate from the generic Suricata rule below since a confirmed-bad indicator match deserves different priority than a heuristic signature match), **Suricata known-malicious netblock** (`siemids-suricata-known-malicious-netblock` -- Spamhaus DROP-listed traffic or TOR relay/router traffic, high severity; split out of the generic Suricata rule below so it can't be buried by future noise-tuning there), **URLhaus domain match** (`siemids-suricata-urlhaus-domain-match`) and **Spamhaus outbound match** (`siemids-suricata-spamhaus-outbound-match`) -- the two new `dataset`/`iprep` rules described above |
| **Network (Suricata)** | Any real Suricata alert signature, excluding entire `alert.category` values that turned out to be pure noise in this deployment (`Generic Protocol Command Decode`, `Device Retrieving External IP Address Detected`, `Misc activity` -- see below) and signatures already owned by a more specific rule; potential outbound SSH scans (excludes this project's own admin/automation hosts *and* GitHub's SSH IP range, `140.82.112.0/20`, since git-over-SSH was the actual source of every remaining false positive) |

Several of the custom rules are tuned against noise this deployment actually generates
(e.g. the firewall-change rule excludes routine Podman/netavark churn). **These are a
starting point, not exhaustive**: review them against your own log sources and threat
model, retune the noise-exclusions, and add rules for your environment.

**False-positive review (2026-07-25)**: `siemids-suricata-real-alerts` was, before this
review, 98% of all detection alerts (8,400 of 8,590) with almost no filtering beyond two
signature names. Traced the volume to `suricata.eve.alert.category`, confirmed each
category's actual source/destination IPs before excluding it, and only then rewrote the
rule -- not a blind broadening of the exclusion list:
- `Device Retrieving External IP Address Detected` (ip-api.com etc.) traced to this
  sensor's own `scripts/interfaces.py` automation (confirmed: source `192.168.100.2`,
  destination `208.95.112.1`, ip-api.com's own IP) -- expected first-party traffic, not
  a threat.
- `Misc activity` (mostly STUN) traced to real household devices' destinations (Google,
  Meta/WhatsApp, likely Teams) -- WebRTC/VoIP NAT traversal from video calls, not attacks.
- `Generic Protocol Command Decode` is truncated-packet/TCP-stream-anomaly noise, already
  effectively excluded before, now excluded more completely (covers all `SURICATA STREAM
  *` variants too, not just the two originally-named signatures).
- The SSH-scan rule's remaining false positives (1,361, all of them) traced to
  destinations `140.82.121.3`/`.4` -- both inside GitHub's `140.82.112.0/20` -- from this
  project's own admin workstation (including its wg0-tunnel identity, a second address
  Suricata sees the *same* physical connection under when captured on a second
  interface) and a separate household device, both doing ordinary `git` operations over
  SSH.

Net effect, confirmed via `_search` against live data before importing: `real-alerts`
221 (was 8,400), `ssh-scan-outbound` 0 new false positives (was 1,361 after the existing
source exclusion alone). The 221 remaining are dominated by Spamhaus DROP/TOR traffic,
now also promoted to their own dedicated, higher-severity rule as noted above.

Unlike dashboards, rules are **not** auto-imported by any compose service -- the
Detection Engine's backing indices only initialize once the Security app has been
opened at least once, which would race against `setup_kibana`'s startup-time import.
Import them yourself, once, after Kibana is up:

  ```bash
  curl -sk -u elastic:<ELASTIC_PASSWORD> -X POST \
    "https://localhost:5601/api/detection_engine/rules/_import?overwrite=true" \
    -H "kbn-xsrf: true" \
    --form file=@saved.objects/detection-rules.ndjson
  ```

  A successful import reports `"success":true,"success_count":24,"errors":[]`. Rules
  are enabled on import; verify in **Security → Rules**, or via:

  ```bash
  curl -sk -u elastic:<ELASTIC_PASSWORD> \
    "https://localhost:5601/api/detection_engine/rules/_find?per_page=100" \
    -H "kbn-xsrf: true"
  ```

### ELK Passwords and Secrets

`start.sh` generates `ELASTIC_PASSWORD`, `KIBANA_PASSWORD`, and `KIBANA_ENCRYPTION_KEY`
on first run only, storing the passwords as both Podman secrets and lines appended to
`.env`, and the encryption key as an `.env` line consumed via
`XPACK_SECURITY_ENCRYPTIONKEY`/`XPACK_ENCRYPTEDSAVEDOBJECTS_ENCRYPTIONKEY`/
`XPACK_REPORTING_ENCRYPTIONKEY` env vars (Kibana's docker entrypoint converts these into
the equivalent `kibana.yml` settings). All three must stay stable across restarts --
Elasticsearch only honors the password at first-ever cluster bootstrap, and Kibana can't
decrypt previously-encrypted saved objects (e.g. stored connector credentials) if the
key changes -- so re-running `start.sh` reuses the existing secrets instead of
regenerating them. Use the `ELASTIC_PASSWORD` to log in at https://localhost:5601.

**`.env` is git-ignored precisely because of this** -- it holds real, live secrets once
`start.sh` has run. Never `git add -f .env`, and never hardcode any of these three
values into a tracked file (an earlier version leaked a password/encryption-key
generation into git history this way). The passwords are also stored as Podman secrets
(`elastic_password`/`kibana_password`, consumed by `setup_pki`) -- see `start.sh` for
the exact generation/storage logic.

### Filebeat Log Collection and Enrichment

`resources/filebeat/filebeat-skynetpi.yml` is Device A's (the ELK host's) Filebeat
config, mounted by the `filebeat` service in `podman-compose.yaml`. Since Device A
isn't the network sensor in this topology, it's deliberately simple: no Suricata
module, no AdGuard input, no `scripts/interfaces.py` dependency -- it ships only
Device A's own OS logs.

  ```bash
  nano resources/filebeat/filebeat-skynetpi.yml
  ```
System logs are collected from the standard path `/var/log`, including files such as *syslog*, *auth.log*, and *audit.log*.

  ```yaml
  filebeat.modules:
  - module: auditd
    log:
      enabled: true
      var.paths: ["/var/log/audit/audit.log*"]
  - module: system
    syslog:
      enabled: true
      var.paths: ["/var/log/syslog*"]
    auth:
      enabled: true
      var.paths: ["/var/log/auth.log*"]
  ```

Ensure that the Filebeat configuration, including file permissions, file paths,
processors, and fields, is properly set up to meet your environment's requirements.
Refer to the [official Filebeat documentation](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-configuration.html)
for additional details.

**Device B's Filebeat config is different and covered separately** -- it's the one
carrying the Suricata module and AdGuard input. The geo-enrichment that powers the
Traffic Flow Map is not a Filebeat processor at all -- it's applied server-side by
Device A's Elasticsearch, via an Enrich processor spliced into the Suricata module's
own ingest pipeline (see [Geo-IP Enrichment](#geo-ip-enrichment-for-private-network-traffic)
below). See
[Device B: Suricata Sensor](#device-b-suricata-sensor-eg-a-raspberry-pi-router) below.

## Ready to start

`start.sh` brings up Device A (`podman-compose`) -- run it there once Device A's
Filebeat config above is set. It does not touch Device B at all; that has no
`podman-compose` and is deployed separately in the next section.

**Note**: Running the `start.sh` script will not affect your running containers, however it will clean your local environment from previous setups and set system parameters required for Elasticsearch on your host and change ownership and permissions of configuration files in `resources/`. This ensures that any previous configurations or data do not interfere with the new setup.
  ```bash
  sudo ./start.sh
  ```
**Yes, you need sudo to ensure that Podman has the necessary permissions.**

- Podman need elevated privileges to perform certain tasks, such as accessing network interfaces, binding to ports below 1024 and due the configuration of certain capabilities (e.g., NET_ADMIN), mounting directories and files that require root access.

## Device B: Suricata Sensor (e.g. a Raspberry Pi router)

Device B (a router/AP-class box, e.g. a Raspberry Pi -- too small to run Elasticsearch)
runs Suricata natively and ships its `eve.json` to Device A with a dedicated,
lightweight Filebeat instance. It has no `podman-compose`, so it's driven by plain
`podman run --restart=always` (see `scripts/*-podman.sh` for examples), not compose.
Device A must already be up before starting here -- these steps assume its TLS certs
already exist.

1. Build a `suricata.yaml` for the sensor host from `resources/suricata/suricata.yaml` (the stock sample) or `resources/suricata/suricata-raspberrysrv.yaml` (a concrete, fully populated multi-interface example), replacing the `af-packet` interface names with the sensor's real interfaces (its AP/LAN and VPN egress interfaces -- not its WAN uplink, unless you want that monitored too), keeping `default-log-dir: /suricata/`.
2. Enable/start it as a native systemd service (`suricata.service`, shipped by the distro package) -- see [Configure Suricata](#configure-suricata). Then run `scripts/suricata-update-timer-install.sh`, which:
   - Enables `et/open` (Emerging Threats Open, ~40k signatures) plus four free IoC feeds via `suricata-update enable-source`: `abuse.ch/feodotracker` (botnet C2 IPs), `abuse.ch/sslbl-blacklist`/`sslbl-ja3` (malicious TLS certs/JA3 fingerprints), and `etnetera/aggressive` (IP blacklist) -- together only a few hundred to ~10k lightweight rules, small next to `et/open`. **Enabling a source is one-time and additive** -- with zero sources enabled, `suricata-update` does *not* fall back to `et/open`, so skipping this step silently leaves the sensor with no real ruleset.
   - Sets up two further custom IoC rules (`resources/suricata/local-rules/`, merged in via `suricata-update --local`) and runs `scripts/refresh-ioc-datasets.sh` to populate the data files they read from: URLhaus's plaintext domain list and Spamhaus's DROP CIDR list. Requires the `reputation-categories-file`/`default-reputation-path`/`reputation-files` block in `suricata.yaml` to be enabled (already set in `resources/suricata/suricata-raspberrysrv.yaml`) for the Spamhaus rule's `iprep` lookup to work.
   - Pulls the rules immediately, then installs a daily-refresh systemd timer (`resources/suricata/suricata-update.service`/`.timer`, `05:00 UTC` + up to 30min random delay) that **live-reloads Suricata with no capture gap** via its `unix-command` socket, refreshing both the signature feeds and the two IoC data files together.
3. Edit `scripts/interfaces.py` **on the sensor host** to set `localnet_1`/`vpnet_1`
   (and `piavpn_1`, if the sensor has a second VPN egress like a PIA tunnel) to that
   host's actual interfaces:

  ```python
  localnet_1 = "eth0" # modify with your local (internet-facing) interface name
  vpnet_1 = "wg0" # modify with your vpn interface name
  #localnet_2 = "wlan1" # modify with your local interface name
  #vpnet_2 = "wg1" # modify with your vpn interface name

  # Second, separate VPN egress (e.g. a PIA tunnel used by a specific
  # container/service alongside the main vpnet_1 VPN). Comment out if not
  # applicable to your setup.
  piavpn_1 = "pia" # modify with your second vpn interface name
  ```

   `localnet_1` must be an interface with a **direct route to the internet** (it's used
   for the public-IP geo lookup) -- on a router/AP box, that's the WAN uplink, not an AP
   interface like `wlan0`/`wlan1` (client traffic on those is force-tunneled through the
   VPN and has no direct egress of its own). The AP subnets' local-IP matching in the
   Elasticsearch enrich policy is separate, hardcoded CIDR logic and unaffected by this
   variable. *Naming the interfaces themselves is still a one-time manual step; keeping
   their enrichment current afterward is automated -- see
   [Geo-IP Enrichment for Private-Network Traffic](#geo-ip-enrichment-for-private-network-traffic)
   below.*
4. Run `scripts/setup-geo-enrichment.sh` **on the sensor host**, once, after Device A is
   up and its certs are copied over (step 5 below) -- it seeds Device A's Elasticsearch
   with this host's current interface geo data and patches the Suricata module's ingest
   pipeline to use it. See
   [Geo-IP Enrichment for Private-Network Traffic](#geo-ip-enrichment-for-private-network-traffic)
   for what it actually does and why enrichment lives there now instead of in Filebeat.
5. If the sensor doesn't already run `auditd`/`rsyslog` (e.g. a journald-only distro like Raspberry Pi OS), install and enable both -- `filebeat-<sensor>.yml`'s `auditd`/`system` modules need `/var/log/audit/audit.log`, `/var/log/syslog` and `/var/log/auth.log` to actually exist.
6. Copy `certs/ca/ca.crt` and `certs/filebeat/{filebeat.crt,filebeat.key}` from the ELK host (generated by its `setup_pki` service after the first `./start.sh` run) onto the sensor host. Set `ELK_LAN_IP` in the ELK host's `.env` to its real LAN IP *before* that first run -- see [Podman Container Security](#podman-container-security) -- otherwise the sensor's Filebeat will fail TLS hostname verification when connecting by IP. `scripts/setup-geo-enrichment.sh` (step 4) and `scripts/filebeat-<sensor>-podman.sh` (step 7) both need these certs to already be in place.
7. Deploy a `resources/filebeat/filebeat-<sensor>.yml` via a `scripts/filebeat-<sensor>-podman.sh` script (see `resources/filebeat/filebeat-raspberrysrv.yml` / `scripts/filebeat-raspberrysrv-podman.sh` for a concrete example), pointing `ELASTICSEARCH_HOSTS` at the ELK host's LAN address and `ELASTICSEARCH_PASSWORD` at its `elastic_password` secret. Besides the `suricata` module, this instance also ships the sensor's own `auditd`/`system` (syslog+auth) logs and, if present, [AdGuard Home](https://github.com/AdguardTeam/AdGuardHome)'s JSON query log (tagged as its own `adguard.log` dataset).

Device A's own `filebeat` service is covered in
[Filebeat Log Collection and Enrichment](#filebeat-log-collection-and-enrichment) above
(`filebeat-skynetpi.yml` -- OS logs only, no Suricata). For a
memory-constrained Device A (e.g. also a Raspberry Pi 4B), use
`podman-compose-skynetpi.yaml` instead of `podman-compose.yaml`.

### Geo-IP Enrichment for Private-Network Traffic

Suricata sees real internal addresses (a client's actual LAN/AP IP, a VPN tunnel's own
assigned IP) that public GeoIP databases have no data for -- MaxMind's `geoip` database
only knows about public IP space. Tagging these with *this deployment's own* known
geography (where the sensor's WAN egress, and its VPN tunnels, actually exit to) is what
powers the private-network side of the Traffic Flow Map; MaxMind's own `geoip` processor
(already built into the Suricata module's ingest pipeline) continues to handle real
public destinations, unaffected by any of this.

This enrichment is **not** a Filebeat processor -- it's an Elasticsearch Enrich
processor, spliced directly into the Suricata module's own auto-registered ingest
pipeline (`filebeat-<version>-suricata-eve-pipeline`) on Device A. It used to be a set of
client-side `add_fields` processors in the sensor's `filebeat-<sensor>.yml`, reading env
vars that were baked into the Filebeat container at *creation* time -- meaning any IP
change (WAN renewed, a VPN tunnel reassigned) required a full container **recreate** to
pick up, which is both disruptive and, since Filebeat's registry isn't persisted here,
carries a real risk of re-reading and duplicate-ingesting the whole `eve.json` file.
Moving it server-side removes that requirement entirely -- updating the enrichment data
is now just two small Elasticsearch API calls, with zero Filebeat downtime.

**How it works**: a small `net-geo-source` index holds one document per matchable
network -- three CIDRs for the sensor's local/AP subnets, one `/32` for the VPN tunnel's
own IP, one `/32` for a second (e.g. PIA) tunnel's own IP -- each carrying that network's
current geo/AS data (from `scripts/interfaces.py`'s same public-IP lookups as before).
Two Enrich policies read from it: `net-geo-cidr` (a `range` policy, matches
`source.ip`/`destination.ip` against the stored CIDRs) and `net-geo-profile` (a `match`
policy, a constant lookup by profile name -- e.g. "give me the VPN tunnel's current exit
geo", used for the synthetic map-layer fields that need it regardless of a given
document's real destination). See `resources/elasticsearch/` for the index mapping,
policy definitions, and the exact patched pipeline. **Known limitation**: don't add a
`/32` (or any more specific range) that overlaps a broader CIDR already in
`net-geo-cidr` -- Elasticsearch's `range` enrich policy does not reliably prefer the more
specific match on overlap. Anything that must overlap needs handling as an explicit
exact-match step in the pipeline instead, ahead of the general CIDR lookup (see the
pipeline patch file for a worked example).

**Keeping it current**: these interfaces' IPs can change on their own (WAN IP on DHCP
renewal, VPN tunnel IPs on reconnect/rotation). `scripts/refresh-filebeat-enrichment.sh`
(installed as a 5-minute systemd timer via
`scripts/refresh-filebeat-enrichment-timer-install.sh`) re-runs `interfaces.py`, and only
if something actually changed, pushes the updated document(s) to `net-geo-source` and
re-executes both enrich policies -- Filebeat itself is never touched for this. Run
`scripts/setup-geo-enrichment.sh` once per sensor before relying on the timer (see step 4
above); it's also safe to re-run later, though changing `net-geo-mapping.json` or
`enrich-policies.json` afterward requires deleting the affected index/policy first --
Elasticsearch doesn't support updating either definition in place.

## Traffic Flow Map

After completing the previous steps, we can now visualize network events using the custom visualizations created for this project. The **Logs Suricata Events Overview** dashboard combines activity-over-time, top source/destination breakdowns, protocol distribution, source/destination geo maps, per-interface activity (`eth0`/`wlan0`/`wlan1`/`wg0`/`pia`), and the Traffic Flow Map itself, highlighting connections and their source/destination countries in one view:

![Suricata Events Overview](resources/images/suricata-events-overview.png)

## OTX Open Threat Exchange (under development)

Add your [OTX AlienVault](https://otx.alienvault.com/) API_KEY to `resources/otx-api.py`

  ```bash
  API_KEY = 'YOUR_OTX_API_KEY'
  ```

To query the OTX API you can use tools like `curl` and `jq`. 
  ```bash
  curl "http://127.0.0.1:5000/threat_intel?ip=<IP_ADDRESS>" | jq .
  ```

Replace `<IP_ADDRESS>` with the IP address you want to query. For example:

  ```bash
  curl "http://127.0.0.1:5000/threat_intel?ip=8.8.8.8" | jq .
  ```

## Screenshots

**Suricata Alert Overview** — top alert signatures and categories, top alerting hosts over time, source/destination countries for alerting traffic, and a dedicated Traffic Flow Map scoped to alerts only:

![Suricata Alert Overview](resources/images/suricata-alert-overview.png)

**DNS Queries** — AdGuard Home integration: queries per source IP, top blocked domains, a permitted-vs-blocked query log timeline, and per-interface query breakdown:

![DNS Queries](resources/images/dns-queries.png)

**Syslog dashboard** — system events (`system.syslog`, `auditd.log`, `system.auth`) broken down by host and by process, across both Device A and Device B:

![Syslog dashboard](resources/images/syslog-dashboard.png)

**SSH login attempts** — successful vs. failed logins over time per host, failed-attempt usernames, and source geolocation:

![SSH login attempts](resources/images/ssh-login-attempts.png)

**Security Alerts** — Kibana's native detection-rule alerts (severity, risk score, rule name) generated from the Suricata signature feed:

![Security Alerts](resources/images/security-alerts.png)

**MITRE ATT&CK® Coverage** — which tactics/techniques the installed detection rules actually cover, at a glance:

![MITRE ATT&CK Coverage](resources/images/mitre-attack-coverage.png)

## Contributing

Contributions are welcome! Please feel free to fork the repository and submit a pull request with your changes.

## License

This repository's own original content (configuration, scripts, documentation) is
licensed under the [MIT License](LICENSE).

It incorporates several third-party open-source components, each under its own license:

- Suricata: Licensed under the [GPLv2 License](https://github.com/OISF/suricata/blob/master/LICENSE).
- Elasticsearch: Licensed under the [Elastic License 2.0](https://www.elastic.co/licensing/elastic-license).
- Kibana: Licensed under the [Elastic License 2.0](https://www.elastic.co/licensing/elastic-license).
- Filebeat: Licensed under the [Elastic License 2.0](https://www.elastic.co/licensing/elastic-license).
- AdGuard Home: Licensed under the [GPLv3 License](https://github.com/AdguardTeam/AdGuardHome/blob/master/LICENSE.txt).

Please refer to the respective project's LICENSE file for more detailed information.