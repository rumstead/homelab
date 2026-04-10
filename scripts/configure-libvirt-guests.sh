#!/bin/bash
# Configure graceful VM shutdown on host reboot
# Without this, libvirt kills VMs abruptly on host shutdown/reboot,
# which corrupts Prometheus WAL/TSDB data and causes total metrics loss.
#
# This configures the libvirt-guests service to gracefully shut down VMs,
# giving Kubernetes time to drain pods and Prometheus time to flush its WAL.

set -e

echo "Configuring libvirt-guests for graceful VM shutdown..."

# Configure libvirt-guests defaults
sudo tee /etc/default/libvirt-guests > /dev/null << 'EOF'
# Action on host shutdown: shutdown (graceful) instead of destroy (kill)
ON_SHUTDOWN=shutdown

# How long to wait (seconds) for VMs to shut down gracefully
# 120s gives Kubernetes enough time to drain pods and Prometheus to flush WAL
SHUTDOWN_TIMEOUT=120

# Number of VMs to shut down in parallel
PARALLEL_SHUTDOWN=2

# Action on host boot: start VMs that were running before shutdown
ON_BOOT=start

# Start VMs in a specific order (0 = no specific order, parallel)
START_DELAY=0
EOF

# Enable and start the libvirt-guests service
sudo systemctl enable libvirt-guests
sudo systemctl start libvirt-guests

echo ""
echo "✓ libvirt-guests configured for graceful shutdown!"
echo ""
echo "Current configuration:"
grep -v '^#' /etc/default/libvirt-guests | grep -v '^$'
echo ""
echo "Verify with:"
echo "  systemctl status libvirt-guests"
echo "  cat /etc/default/libvirt-guests"
echo ""
echo "On next host reboot, VMs will shut down gracefully (up to 120s)"
echo "instead of being killed, preserving Prometheus metrics data."
