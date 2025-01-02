#!/bin/bash
#sudo systemctl restart suricata
sudo sh -x scripts/prune.sh
sudo sh -x scripts/pre-podman-launch.sh
python3 scripts/interfaces.py

# Generate random passwords
ELASTIC_PASSWORD=$(openssl rand -base64 12)
KIBANA_PASSWORD=$(openssl rand -base64 12)

# Create Podman secrets
# Write the passwords to the .env file
sed -i "/^ELASTIC_PASSWORD=/d" .env
sed -i "/^KIBANA_PASSWORD=/d" .env
echo "ELASTIC_PASSWORD=$ELASTIC_PASSWORD" >> .env
echo "KIBANA_PASSWORD=$KIBANA_PASSWORD" >> .env

# Create Podman secrets
echo -n "$ELASTIC_PASSWORD" | sudo podman secret create elastic_password -
echo -n "$KIBANA_PASSWORD" | sudo podman secret create kibana_password -

# Pass the environment variables to each container
sudo podman-compose up -d
