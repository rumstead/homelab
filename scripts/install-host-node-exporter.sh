#!/bin/bash
# Install node_exporter on the Ubuntu host machine
# This exposes host metrics on port 9100 for Prometheus to scrape

set -e

NODE_EXPORTER_VERSION="1.10.2"

echo "Installing node_exporter ${NODE_EXPORTER_VERSION} on host..."

# Download
cd /tmp
curl -LO "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"

# Install binary
sudo mv "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
sudo chmod +x /usr/local/bin/node_exporter

# Create systemd service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null << 'EOF'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/node_exporter
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter

# Cleanup
rm -rf /tmp/node_exporter-*

echo ""
echo "✓ node_exporter installed and running!"
echo ""
echo "Verify with:"
echo "  curl http://localhost:9100/metrics | head"
echo ""
echo "Prometheus will scrape this at: http://192.168.1.50:9100"
