#!/bin/bash
sudo systemctl restart suricata
sudo sh -x scripts/pre-podman-launch.sh
python3 scripts/deploy.py; sudo podman-compose up -d
