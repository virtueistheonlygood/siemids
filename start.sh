#!/usr/bin/env bash
set -e

# Ensure the script is run as sudo
if [ "$EUID" -ne 0 ]; then
    #sudo "$0" "$@"
    echo ""
    echo "******************"
    echo "** Run as sudo! **"
    echo "******************"
    echo "Podman need elevated privileges to perform certain tasks, such as accessing network interfaces, binding to ports below 1024 and due the configuration of certain capabilities (e.g., NET_ADMIN), mounting directories and files that require root access."
    echo ""
    echo "sudo ./start.sh"
    echo ""
    exit $?
fi

# Uncomment if you need to restart suricata
# sudo systemctl restart suricata

# Cleaning script
sh -x scripts/prune.sh
sh -x scripts/pre-podman-launch.sh

# Generate env and geoip information for Filebeat enrichment to be used in Kibana dashboards combined with Suricata logs.
# Only needed on hosts running a network sensor's Filebeat (source.ip/destination.ip
# enrichment) -- an ELK-only host has nothing local to enrich and won't have this file.
if [ -f scripts/interfaces.py ]; then
    python3 scripts/interfaces.py
fi

# Generate ELK passwords and Kibana's encryption key only on first run.
# Elasticsearch's elastic/kibana_system passwords are set from these just
# once, at first-ever cluster bootstrap, and persisted into the .security
# index inside the elasticsearchdata volume -- ES does NOT reset them on
# subsequent starts. Kibana's encryptionKey (security/encryptedSavedObjects/
# reporting) similarly must stay stable, or saved objects encrypted with the
# old key (e.g. stored connector/action credentials) become unreadable.
# Regenerating any of these on every run desyncs the secret from what's
# actually enforced/already encrypted, breaking auth or decryption after any
# restart. See DEPLOYMENT.md.
if podman secret ls --format '{{.Name}}' | grep -qx 'elastic_password'; then
    echo "ELK secrets already exist -- reusing existing passwords."
else
    ELASTIC_PASSWORD=$(openssl rand -base64 12)
    KIBANA_PASSWORD=$(openssl rand -base64 12)
    KIBANA_ENCRYPTION_KEY=$(openssl rand -base64 32)

    # Create temporary file for .env
    ENV_FILE=$(mktemp)
    trap 'rm -f "$ENV_FILE"' EXIT

    # Write the passwords to the .env file
    sed -e "/^ELASTIC_PASSWORD=/d" -e "/^KIBANA_PASSWORD=/d" -e "/^KIBANA_ENCRYPTION_KEY=/d" .env > "$ENV_FILE"
    cp "$ENV_FILE" .env
    echo "ELASTIC_PASSWORD=$ELASTIC_PASSWORD" >> .env
    echo "KIBANA_PASSWORD=$KIBANA_PASSWORD" >> .env
    echo "KIBANA_ENCRYPTION_KEY=$KIBANA_ENCRYPTION_KEY" >> .env

    # Create Podman secrets
    echo -n "$ELASTIC_PASSWORD" | podman secret create elastic_password -
    echo -n "$KIBANA_PASSWORD" | podman secret create kibana_password -
fi

# Check if podman-compose is installed and launch the project
if command -v podman-compose >/dev/null 2>&1; then
    podman-compose up -d
else
    echo "podman-compose is not installed, please review README.md."
    exit 1
fi
