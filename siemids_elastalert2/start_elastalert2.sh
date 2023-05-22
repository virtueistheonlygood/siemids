#!/bin/bash
docker run -d --name siemids_elastalert2 -v /home/skynet/siemids/elastalert2/certs:/opt/elastalert/certs -v /home/skynet/siemids/elastalert2/rules:/opt/elastalert/rules --network siemids_default siemids_elastalert2
