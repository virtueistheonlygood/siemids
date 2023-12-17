import requests
import json

OTX_API_KEY = "4daa2a9e13deb6172bb8c79e6768ca3ebb6ed1b7bf986bb594e5e0287cfbad4a"
OTX_BASE_URL = "https://otx.alienvault.com/api/v1"

def query_otx(ip):
    headers = {"X-OTX-API-KEY": OTX_API_KEY}
    url = f"{OTX_BASE_URL}/indicators/IPv4/{ip}/"

    response = requests.get(url, headers=headers)
    if response.status_code == 200:
        data = response.json()
        return data
    else:
        print(f"Failed to query OTX for IP {ip}. Status code: {response.status_code}")
        return None

# Read Suricata EVE JSON and extract IPs
with open("/suricata/eve.json", "r") as eve_file:
    for line in eve_file:
        event = json.loads(line)
        if "dest_ip" in event:
            ip = event["dest_ip"]
            otx_data = query_otx(ip)
            if otx_data:
                print(f"Threat information for IP {ip}: {otx_data}")

