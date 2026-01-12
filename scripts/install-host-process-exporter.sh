#!/bin/bash
# Install process-exporter on the Ubuntu host machine
# This exposes process-level metrics on port 9256 for Prometheus to scrape

set -e

PROCESS_EXPORTER_VERSION="0.8.3"

echo "Installing process-exporter ${PROCESS_EXPORTER_VERSION} on host..."

# Download
cd /tmp
curl -LO "https://github.com/ncabatoff/process-exporter/releases/download/v${PROCESS_EXPORTER_VERSION}/process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64.tar.gz"
tar xzf "process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Install binary
sudo mv "process-exporter-${PROCESS_EXPORTER_VERSION}.linux-amd64/process-exporter" /usr/local/bin/
sudo chmod +x /usr/local/bin/process-exporter

# Create config file
sudo mkdir -p /etc/process-exporter
sudo tee /etc/process-exporter/config.yml > /dev/null << 'EOF'
process_names:
  # Match processes by command name
  - name: "{{.Comm}}"
    cmdline:
    - '.+'
EOF

# Create systemd service
sudo tee /etc/systemd/system/process_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Prometheus Process Exporter
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/process-exporter -config.path=/etc/process-exporter/config.yml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable process_exporter
sudo systemctl start process_exporter

# Cleanup
rm -rf /tmp/process-exporter-*

echo ""
echo "✓ process-exporter installed and running on port 9256!"
echo ""
echo "Verify with:"
echo "  curl http://localhost:9256/metrics | grep namedprocess"
echo ""
echo "Next steps:"
echo "1. Add process-exporter scrape target to your Prometheus configuration"
echo "2. Ensure ubuntu-host servicemonitor includes port 9256"
echo ""
