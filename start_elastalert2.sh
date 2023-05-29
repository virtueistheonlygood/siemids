#!/bin/bash
#docker cp siemids_es01_1:/usr/share/elasticsearch/config/certs/ elastalert/.
sudo chown -R $USER:$USER $PWD/certs
docker run -d --name siemids_elastalert2 -v $PWD/certs:/opt/elastalert/certs:ro -v $PWD/elastalert/rules:/opt/elastalert/rules --network siemids_default siemids_elastalert2
