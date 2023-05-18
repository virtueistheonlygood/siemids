import subprocess
import requests
import json

call = "curl -sS"
myip = "ifconfig.me"
raspi = "ssh pi@raspberrysrv"
localnet_if = "--interface eth0"
ovpnnet_if = "--interface tun0"
pianet_if = "--interface pia"
ipapi = "http://ip-api.com/json/"

# Get local IP and geo ifacermation
localnet = subprocess.check_output(f"{raspi} {call} {localnet_if} {myip}", shell=True, text=True).strip()
localnet_geo = requests.get(f"{ipapi}{localnet}").json()
with open("geoip/localnet.json", "w") as f:
    json.dump(localnet_geo, f)

# Get network ifacermation for all local interfaces
localnet_iface = {}
for interface in ["eth0", "wlan0", "wlan1"]:
    output = subprocess.check_output(f"{raspi} ip a show dev {interface}", shell=True, text=True)
    ip_address = output.split("inet ")[1].split("/")[0].strip()
    localnet_iface[interface] = ip_address

# Save all output to localnet.json
with open("geoip/localnet.json", "w") as f:
    output = {
        "localnet_geo": localnet_geo,
        "localnet_iface": localnet_iface
    }
    json.dump(output, f)

# Get wireguard-pia public IP and geo ifacermation
pianet = subprocess.check_output(f"{raspi} {call} {pianet_if} {myip}", shell=True, text=True).strip()
pianet_geo = requests.get(f"{ipapi}{pianet}").json()
with open("geoip/pianet.json", "w") as f:
    json.dump(pianet_geo, f)

# Get network ifacermation for pia local interface
pianet_iface = {}
for interface in ["pia"]:
    output = subprocess.check_output(f"{raspi} ip a show dev {interface}", shell=True, text=True)
    ip_address = output.split("inet ")[1].split("/")[0].strip()
    pianet_iface[interface] = ip_address

# Save all output to pianet.json
with open("geoip/pianet.json", "w") as f:
    output = {
        "pianet_geo": pianet_geo,
        "pianet_iface": pianet_iface
    }
    json.dump(output, f)

# Get openvpn-pia public IP and geo ifacermation
ovpnnet = subprocess.check_output(f"{raspi} {call} {ovpnnet_if} {myip}", shell=True, text=True).strip()
ovpnnet_geo = requests.get(f"{ipapi}{ovpnnet}").json()
with open("geoip/ovpnnet.json", "w") as f:
    json.dump(ovpnnet_geo, f)

# Get network ifacermation for tun0 local interface
ovpnnet_iface = {}
for interface in ["tun0"]:
    output = subprocess.check_output(f"{raspi} ip a show dev {interface}", shell=True, text=True)
    ip_address = output.split("inet ")[1].split("/")[0].strip()
    ovpnnet_iface[interface] = ip_address

# Save all output to ovpnnet.json
with open("geoip/ovpnnet.json", "w") as f:
    output = {
        "ovpnnet_geo": ovpnnet_geo,
        "ovpnnet_iface": ovpnnet_iface
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

with open('geoip/ovpnnet.json', 'r') as f:
    config = json.load(f)

with open('env/ovpnnet.env', 'w') as f:
    for key, value in config.items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                f.write(f'{key}_{subkey.upper()}={subvalue}\n')
        else:
            f.write(f'{key.upper()}={value}\n')

with open('geoip/pianet.json', 'r') as f:
    config = json.load(f)

with open('env/pianet.env', 'w') as f:
    for key, value in config.items():
        if isinstance(value, dict):
            for subkey, subvalue in value.items():
                f.write(f'{key}_{subkey.upper()}={subvalue}\n')
        else:
            f.write(f'{key.upper()}={value}\n')

import docker
import os

# Create a Docker client object
client = docker.from_env()

# Find the container by name
container = client.containers.get('siemids_filebeat-raspberrysrv_1')

# Stop the container
container.stop()

# Delete the container
container.remove()

# Change to the directory containing the docker-compose.yml file
os.chdir('/home/skynet/siemids/')

# Start the services defined in docker-compose.yml
os.system('docker-compose up -d')
