#!/bin/bash
# Set up a daily systemd timer on the Ubuntu host to run apt and snap updates
# Installs /usr/local/bin/host-auto-update.sh plus a systemd service+timer pair

set -e

echo "Installing host auto-update script and systemd timer..."

# Update script
sudo tee /usr/local/bin/host-auto-update.sh > /dev/null << 'EOF'
#!/bin/bash
set -euo pipefail

echo "=== $(date) : apt update/upgrade ==="
apt-get update
apt-get upgrade -y
apt-get autoremove -y

echo "=== $(date) : snap refresh ==="
snap refresh
EOF
sudo chmod +x /usr/local/bin/host-auto-update.sh

# systemd service (runs the script once when triggered)
sudo tee /etc/systemd/system/host-auto-update.service > /dev/null << 'EOF'
[Unit]
Description=Host apt/snap auto-update

[Service]
Type=oneshot
ExecStart=/usr/local/bin/host-auto-update.sh
EOF

# systemd timer (triggers the service once daily)
sudo tee /etc/systemd/system/host-auto-update.timer > /dev/null << 'EOF'
[Unit]
Description=Daily host apt/snap auto-update

[Timer]
OnCalendar=daily
RandomizedDelaySec=30min
Persistent=true

[Install]
WantedBy=timers.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now host-auto-update.timer

echo ""
echo "✓ host-auto-update.timer installed and enabled!"
echo ""
echo "Check status with:"
echo "  systemctl status host-auto-update.timer"
echo "  systemctl list-timers host-auto-update.timer"
echo ""
echo "Run it immediately with:"
echo "  sudo systemctl start host-auto-update.service"
echo ""
echo "View logs with:"
echo "  journalctl -u host-auto-update.service"
