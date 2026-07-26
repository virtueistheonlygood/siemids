import subprocess
import json

### Edit before running "sudo ./start.sh"
### Run this on the host that actually carries the traffic being enriched --
### for the raspberrypi Suricata sensor, that's the Pi itself, not the ELK
### host. localnet_1 must be an interface with a direct route to the
### internet (used for the public-IP geo lookup below) -- on a router/AP
### box like this Pi that's the WAN uplink (eth0), NOT the AP interface
### (wlan0/wlan1) itself, since client traffic on those is force-tunneled
### through the VPN interface and has no direct egress of its own. The
### wlan0/wlan1 local-subnet matching in filebeat's processors (10.10.10.,
### 10.1.1.) is independent hardcoded IP-prefix logic and unaffected by
### this variable.
localnet_1 = "eth0" # modify with your local (internet-facing) interface name
vpnet_1 = "wg0" # modify with your vpn interface name
#localnet_2 = "wlan1" # modify with your local interface name
#vpnet_2 = "wg1" # modify with your vpn interface name

# Second, separate VPN egress (e.g. a PIA tunnel used by a specific
# container/service alongside the main vpnet_1 VPN). Comment out if not
# applicable to your setup.
piavpn_1 = "pia" # modify with your second vpn interface name

localnet1_if = f"--interface {localnet_1}"
vpnet1_if = f"--interface {vpnet_1}"
piavpn1_if = f"--interface {piavpn_1}"
#localnet2_if = f"--interface {localnet_2}" # uncomment if you have more than one local interface
#vpnet2_if = "f--interface {vpnet_2}" # uncomment if you have more than one vpn interface

call = "curl -sS"
ipapi = "http://ip-api.com/json/"

# ip-api.com returns geo info (including the caller's own public IP, in the
# "query" field) for whichever IP made the request -- querying it directly
# via --interface X in one shot gets both pieces of data at once, and avoids
# a separate IP-echo lookup (ifconfig.me is deliberately blocked network-wide
# by AdGuard as a known tracking/fingerprinting domain, unlike the
# geoip.elastic.co false-positive documented in DEPLOYMENT.md -- this isn't
# something to allowlist, since that would reopen it for every LAN client,
# not just this script).

# Get local IP and geo information for localnet_1 interface
localnet_geo = json.loads(subprocess.check_output(f"{call} {localnet1_if} {ipapi}", shell=True, text=True))
with open("geoip/localnet.json", "w") as f:
    json.dump(localnet_geo, f)

# Get network information for localnet_1 interface
localnet_iface = {}
for interface in [localnet_1]:
    output = subprocess.check_output(f"ip a show dev {interface}", shell=True, text=True)
    ip_address = output.split("inet ")[1].split("/")[0].strip()
    localnet_iface[interface] = ip_address

# Save localnet_1 details to localnet.json
with open("geoip/localnet.json", "w") as f:
    output = {
        "localnet_geo": localnet_geo,
        "localnet_iface": localnet_iface
    }
    json.dump(output, f)

# Get vpnet_1 public IP and geo information
vpnet_geo = json.loads(subprocess.check_output(f"{call} {vpnet1_if} {ipapi}", shell=True, text=True))
with open("geoip/vpnet.json", "w") as f:
    json.dump(vpnet_geo, f)

# Get network information for vpnet_1 interface
vpnet_iface = {}
for interface in [vpnet_1]:
    output = subprocess.check_output(f"ip a show dev {interface}", shell=True, text=True)
    ip_address = output.split("inet ")[1].split("/")[0].strip()
    vpnet_iface[interface] = ip_address

# Save vpnet_1  details to vpnet.json
with open("geoip/vpnet.json", "w") as f:
    output = {
        "vpnet_geo": vpnet_geo,
        "vpnet_iface": vpnet_iface
    }
    json.dump(output, f)

# Get piavpn_1 public IP and geo information
piavpn_geo = json.loads(subprocess.check_output(f"{call} {piavpn1_if} {ipapi}", shell=True, text=True))
with open("geoip/piavpn.json", "w") as f:
    json.dump(piavpn_geo, f)

# Get network information for piavpn_1 interface
piavpn_iface = {}
for interface in [piavpn_1]:
    output = subprocess.check_output(f"ip a show dev {interface}", shell=True, text=True)
    ip_address = output.split("inet ")[1].split("/")[0].strip()
    piavpn_iface[interface] = ip_address

# Save piavpn_1 details to piavpn.json
with open("geoip/piavpn.json", "w") as f:
    output = {
        "piavpn_geo": piavpn_geo,
        "piavpn_iface": piavpn_iface
    }
    json.dump(output, f)

# Push the same data to Elasticsearch instead of writing env/*.env -- geo
# enrichment is now done server-side by two Enrich policies (net-geo-cidr,
# net-geo-profile; see resources/elasticsearch/) reading from the
# net-geo-source index, not by Filebeat's own client-side add_fields
# reading these values in at container-creation time. This means an IP
# change no longer requires recreating Filebeat (see
# scripts/refresh-filebeat-enrichment.sh) -- it only needs these documents
# updated and the two policies re-executed, both cheap ES API calls.
#
# Requires env/elk.env (ELASTICSEARCH_HOSTS/ELASTICSEARCH_PASSWORD) and
# certs/ca/ca.crt -- same prerequisites filebeat-raspberrysrv-podman.sh
# already has. No error handling here either, consistent with the rest of
# this script: if elk.env or the certs are missing, or the ES host is
# unreachable, this just throws and exits non-zero.

def read_env_file(path):
    values = {}
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            values[k] = v
    return values


def geo_fields(geo):
    return {
        "location": f"POINT ({geo.get('lon')} {geo.get('lat')})",
        "country_name": geo.get("country"),
        "country_iso_code": geo.get("countryCode"),
        "region_iso_code": geo.get("region"),
        "continent_name": geo.get("timezone"),
        "region_name": geo.get("regionName"),
        "city_name": geo.get("city"),
    }


def as_fields(geo):
    return {"organization": {"name": geo.get("org")}}


def push_doc(es_host, es_password, doc_id, body):
    subprocess.run(
        [
            "curl", "-sS", "--fail", "--cacert", "certs/ca/ca.crt",
            "-u", f"elastic:{es_password}",
            "-X", "PUT", f"{es_host}/net-geo-source/_doc/{doc_id}",
            "-H", "Content-Type: application/json",
            "-d", json.dumps(body),
        ],
        check=True, capture_output=True,
    )


elk_env = read_env_file("env/elk.env")
es_host = elk_env["ELASTICSEARCH_HOSTS"]
es_password = elk_env["ELASTICSEARCH_PASSWORD"]

# Same ranges as the "Local Networks" / "WireGuard" / "PIA VPN" blocks this
# replaces in filebeat-raspberrysrv.yml. The two dnsmasq_pia-related "DNS PIA
# UPSTREAM" IPs (192.168.100.200, 10.0.0.243) are intentionally NOT CIDR
# entries here -- 192.168.100.200 overlaps with the 192.168.100.0/24 localnet
# range below, and Elasticsearch's range enrich policy does not reliably
# prefer the more specific match on overlap (confirmed via _simulate:
# resolved to localnet's geo instead of piavpn's). Those two IPs are matched
# by exact equality directly in the pipeline instead (see
# resources/elasticsearch/suricata-eve-pipeline-patch.json), falling back to
# this CIDR policy otherwise -- no overlap, no ambiguity.
local_cidrs = ["10.1.1.0/24", "10.10.10.0/24", "192.168.100.0/24"]

docs = {}
for i, cidr in enumerate(local_cidrs):
    docs[f"localnet-{i}"] = {
        "profile": "localnet", "cidr": cidr,
        "geo": geo_fields(localnet_geo), "as": as_fields(localnet_geo),
    }

docs["vpnet-iface"] = {
    "profile": "vpnet", "cidr": f"{vpnet_iface[vpnet_1]}/32",
    "geo": geo_fields(vpnet_geo), "as": as_fields(vpnet_geo),
}

docs["piavpn-iface"] = {
    "profile": "piavpn", "cidr": f"{piavpn_iface[piavpn_1]}/32",
    "geo": geo_fields(piavpn_geo), "as": as_fields(piavpn_geo),
}

for doc_id, body in docs.items():
    push_doc(es_host, es_password, doc_id, body)