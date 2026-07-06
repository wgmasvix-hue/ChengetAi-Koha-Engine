#!/bin/bash
set -e

echo "======================================"
echo " ChengetAi Koha Engine Installer"
echo "======================================"

docker compose pull
docker compose up -d

echo
echo "Koha services started successfully."
