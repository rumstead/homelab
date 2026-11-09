#!/bin/bash
set -euo pipefail

echo "=== $(date) : apt update/upgrade ==="
apt-get update
apt-get upgrade -y
apt-get autoremove -y

echo "=== $(date) : snap refresh ==="
snap refresh
