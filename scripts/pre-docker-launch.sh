sudo sysctl -w vm.max_map_count=262144
cd /home/skynet/github-repos/siemids/scripts
sudo chown root:root ../resources/filebeat/filebeat*.yml ../resources/suricata/suricata* 
