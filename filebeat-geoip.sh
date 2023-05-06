#!/bin/bash
call="curl -sS"
myip=ifconfig.me
raspi="ssh pi@raspberrysrv"
local="--interface eth0"
ovpn="--interface tun0"
wireguard="--interface pia"
#ipinfo=ipinfo.io
ipapi=ip-api.com

localnetworks=`$raspi $call $local $myip`
localnetworks_location=`$call $ipapi/json/$localnetworks | jq -r 'to_entries | map("  \(.key): \(.value | tojson)") | .[]' > geoip/localnetworks.yml`

ovpnnetwork=`$raspi $call $ovpn $myip`
ovpnnetwork_location=`$call $ipapi/json/$ovpnnetwork | jq -r 'to_entries | map("  \(.key): \(.value | tojson)") | .[]' > geoip/ovpnnetwork.yml`

pianetwork=`$raspi $call $wireguard $myip`
pianetwork_location=`$call $ipapi/json/$pianetwork | jq -r 'to_entries | map("  \(.key): \(.value | tojson)") | .[]' > geoip/pianetwork.yml`
