#!/bin/bash
sudo systemctl restart suricata
sudo sh -x scripts/pre-docker-launch.sh
python3 scripts/deploy.py
