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

# Generate corresponding environments to be used as variables on filebeat processors
with open('geoip/localnet.json', 'r') as f:
    config = json.load(f)

with open('env/localnet.env', 'w') as f:
    for key, value in config.items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                f.write(f'{key}_{subkey.upper()}={subvalue}\n')
        else:
            f.write(f'{key.upper()}={value}\n')

with open('geoip/vpnet.json', 'r') as f:
    config = json.load(f)

with open('env/vpnet.env', 'w') as f:
    for key, value in config.items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                f.write(f'{key}_{subkey.upper()}={subvalue}\n')
        else:
            f.write(f'{key.upper()}={value}\n')

with open('geoip/piavpn.json', 'r') as f:
    config = json.load(f)

with open('env/piavpn.env', 'w') as f:
    for key, value in config.items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                f.write(f'{key}_{subkey.upper()}={subvalue}\n')
        else:
            f.write(f'{key.upper()}={value}\n')