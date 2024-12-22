#!/bin/bash
#docker cp siemids_es01_1:/usr/share/elasticsearch/config/certs/ elastalert/.
sudo chown -R $USER:$USER /home/skynet/Downloads/github-repos/siemids/certs
docker run -d --name siemids_elastalert2 -v /home/skynet/Downloads/github-repos/siemids/certs:/opt/elastalert/certs:ro -v /home/skynet/Downloads/github-repos/siemids/elastalert/rules:/opt/elastalert/rules --network siemids_default siemids_elastalert2
