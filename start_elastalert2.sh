#!/bin/bash
docker cp siemids_es01_1:/usr/share/elasticsearch/config/certs/ elastalert/.
docker run -d --name siemids_elastalert2 -v $HOME/siemids/elastalert/certs:/opt/elastalert/certs -v $HOME/siemids/elastalert/rules:/opt/elastalert/rules --network siemids_default siemids_elastalert2
