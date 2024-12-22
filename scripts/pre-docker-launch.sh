sudo sysctl -w vm.max_map_count=262144
cd /home/skynet/Downloads/github-repos/siemids/scripts
sudo chown root:root ../resources/filebeat/filebeat*.yml ../resources/suricata/suricata*
sudo chmod go-w ../resources/filebeat/filebeat*.yml
podman system prune -f
podman volume prune -f
