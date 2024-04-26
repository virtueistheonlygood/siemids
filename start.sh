#!/bin/bash
sudo sh -x scritps/prune.sh
sudo sh -x scripts/pre-docker-launch.sh
python3 scripts/deploy.py
