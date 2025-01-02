sudo sysctl -w vm.max_map_count=262144
cd /home/skynet/Downloads/github-repos/siemids/scripts
sudo chown root:root ../resources/*beat/*.yml ../resources/suricata/suricata*
sudo chmod go-w ../resources/*beat/*.yml
sudo podman system prune -f
sudo podman volume prune -f
