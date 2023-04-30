echo -n "WireGuard PIA IP: "
ssh pi@raspberrysrv ip a show dev pia|grep inet|awk '{print$2}'|sed 's|/32||'
echo -n "OpenVPN PIA IP: "
ssh pi@raspberrysrv ip a show dev tun0|grep inet|awk '{print$2}'|sed 's|/24||'
