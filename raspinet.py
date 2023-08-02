import subprocess
import requests
import json

call = "curl -sS"
myip = "ifconfig.me"
localnet_if = "--interface wlan0"
pianet_if = "--interface wg0"
ipapi = "http://ip-api.com/json/"

# Get local IP and geo information
localnet = subprocess.check_output(f"{call} {localnet_if} {myip}", shell=True, text=True).strip()
localnet_geo = requests.get(f"{ipapi}{localnet}").json()
with open("geoip/localnet.json", "w") as f:
    json.dump(localnet_geo, f)

# Get network information for all local interfaces
localnet_iface = {}
for interface in ["wlan0"]:
    output = subprocess.check_output(f"ip a show dev {interface}", shell=True, text=True)
    ip_address = output.split("inet ")[1].split("/")[0].strip()
    localnet_iface[interface] = ip_address

# Save all output to localnet.json
with open("geoip/localnet.json", "w") as f:
    output = {
        "localnet_geo": localnet_geo,
        "localnet_iface": localnet_iface
    }
    json.dump(output, f)

# Get wireguard-pia public IP and geo information
pianet = subprocess.check_output(f"{call} {pianet_if} {myip}", shell=True, text=True).strip()
pianet_geo = requests.get(f"{ipapi}{pianet}").json()
with open("geoip/pianet.json", "w") as f:
    json.dump(pianet_geo, f)

# Get network information for pia local interface
pianet_iface = {}
for interface in ["wg0"]:
    output = subprocess.check_output(f"ip a show dev {interface}", shell=True, text=True)
    ip_address = output.split("inet ")[1].split("/")[0].strip()
    pianet_iface[interface] = ip_address

# Save all output to pianet.json
with open("geoip/pianet.json", "w") as f:
    output = {
        "pianet_geo": pianet_geo,
        "pianet_iface": pianet_iface
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
container = client.containers.get('siemids_filebeat-elitebook_1')

# Stop the container
container.stop()

# Delete the container
container.remove()

# Change to the directory containing the docker-compose.yml file
os.chdir('/home/skynet/siemids/')

# Start the services defined in docker-compose.yml
os.system('docker-compose up -d')
