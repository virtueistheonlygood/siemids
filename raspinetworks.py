import subprocess
import requests
import json

call = "curl -sS"
myip = "ifconfig.me"
raspi = "ssh pi@raspberrysrv"
local = "--interface eth0"
ovpn = "--interface tun0"
pia = "--interface pia"
ipapi = "ip-api.com"

localnetworks = subprocess.check_output(f"{raspi} {call} {local} {myip}", shell=True, text=True).strip()
localnetworks_location = requests.get(f"http://{ipapi}/json/{localnetworks}").json()
with open("geoip/localnetworks.yml", "w") as f:
    f.write(f"  country: {localnetworks_location['country']}\n")
    f.write(f"  countryCode: {localnetworks_location['countryCode']}\n")
    f.write(f"  region: {localnetworks_location['region']}\n")
    f.write(f"  regionName: {localnetworks_location['regionName']}\n")
    f.write(f"  city: {localnetworks_location['city']}\n")
    f.write(f"  zip: {localnetworks_location['zip']}\n")
    f.write(f"  lat: {localnetworks_location['lat']}\n")
    f.write(f"  lon: {localnetworks_location['lon']}\n")
    f.write(f"  timezone: {localnetworks_location['timezone']}\n")
    f.write(f"  isp: {localnetworks_location['isp']}\n")
    f.write(f"  org: {localnetworks_location['org']}\n")
    f.write(f"  as: {localnetworks_location['as']}\n")
    f.write(f"  query: {localnetworks_location['query']}\n")

subprocess.run(f"./raspinetworks.sh | grep eth0 >> geoip/localnetworks.yml", shell=True)

subprocess.run(f"./raspinetworks.sh | grep wlan0 >> geoip/localnetworks.yml", shell=True)

subprocess.run(f"./raspinetworks.sh | grep wlan1 >> geoip/localnetworks.yml", shell=True)

pianetwork = subprocess.check_output(f"{raspi} {call} {pia} {myip}", shell=True, text=True).strip()
pianetwork_location = requests.get(f"http://{ipapi}/json/{pianetwork}").json()
with open("geoip/pianetwork.yml", "w") as f:
    f.write(f"  country: {pianetwork_location['country']}\n")
    f.write(f"  countryCode: {pianetwork_location['countryCode']}\n")
    f.write(f"  region: {pianetwork_location['region']}\n")
    f.write(f"  regionName: {pianetwork_location['regionName']}\n")
    f.write(f"  city: {pianetwork_location['city']}\n")
    f.write(f"  zip: {pianetwork_location['zip']}\n")
    f.write(f"  lat: {pianetwork_location['lat']}\n")
    f.write(f"  lon: {pianetwork_location['lon']}\n")
    f.write(f"  timezone: {pianetwork_location['timezone']}\n")
    f.write(f"  isp: {pianetwork_location['isp']}\n")
    f.write(f"  org: {pianetwork_location['org']}\n")
    f.write(f"  as: {pianetwork_location['as']}\n")   
    f.write(f"  query: {pianetwork_location['query']}\n")

subprocess.run(f"./raspinetworks.sh | grep pia >> geoip/pianetwork.yml", shell=True)

ovpnnetwork = subprocess.check_output(f"{raspi} {call} {ovpn} {myip}", shell=True, text=True).strip()
ovpnnetwork_location = requests.get(f"http://{ipapi}/json/{ovpnnetwork}").json()
with open("geoip/ovpnnetwork.yml", "w") as f:
    f.write(f"  country: {ovpnnetwork_location['country']}\n")
    f.write(f"  countryCode: {ovpnnetwork_location['countryCode']}\n")
    f.write(f"  region: {ovpnnetwork_location['region']}\n")
    f.write(f"  regionName: {ovpnnetwork_location['regionName']}\n")
    f.write(f"  city: {ovpnnetwork_location['city']}\n")
    f.write(f"  zip: {ovpnnetwork_location['zip']}\n")
    f.write(f"  lat: {ovpnnetwork_location['lat']}\n")
    f.write(f"  lon: {ovpnnetwork_location['lon']}\n")
    f.write(f"  timezone: {ovpnnetwork_location['timezone']}\n")
    f.write(f"  isp: {ovpnnetwork_location['isp']}\n")
    f.write(f"  org: {ovpnnetwork_location['org']}\n")
    f.write(f"  as: {ovpnnetwork_location['as']}\n")
    f.write(f"  query: {ovpnnetwork_location['query']}\n")

subprocess.run(f"./raspinetworks.sh | grep tun0 >> geoip/ovpnnetwork.yml", shell=True)

