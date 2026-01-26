#!/bin/bash
# Add persistent disk mount to Talos machine configurations
# This script patches the existing machine configs to mount /dev/vdb at /mnt/persistent

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TALOS_DIR="$PROJECT_DIR/talos"

PERSISTENT_MOUNT_PATH="${PERSISTENT_MOUNT_PATH:-/var/lib/persistent}"
CONTROL_PLANE_IP="192.168.1.245"
WORKER_IP="192.168.1.222"

echo "================================================"
echo "Add Persistent Disk Mount to Talos VMs"
echo "================================================"
echo ""
echo "This will configure both VMs to mount /dev/vdb at $PERSISTENT_MOUNT_PATH"
echo ""

# Create the machine config patch
cat > /tmp/persistent-disk-patch.yaml << EOF
machine:
  disks:
    - device: /dev/vdb
      partitions:
        - mountpoint: $PERSISTENT_MOUNT_PATH
EOF

echo "Disk mount configuration:"
cat /tmp/persistent-disk-patch.yaml
echo ""

# Apply to control plane
echo "Applying to control plane ($CONTROL_PLANE_IP)..."
talosctl apply-config \
  --nodes $CONTROL_PLANE_IP \
  --file "$TALOS_DIR/controlplane.yaml" \
  --config-patch @/tmp/persistent-disk-patch.yaml \
  --mode reboot

echo "✓ Control plane config applied (rebooting)"
echo ""

# Wait a bit for control plane to start rebooting
sleep 5

# Apply to worker
echo "Applying to worker ($WORKER_IP)..."
talosctl apply-config \
  --nodes $WORKER_IP \
  --file "$TALOS_DIR/worker.yaml" \
  --config-patch @/tmp/persistent-disk-patch.yaml \
  --mode reboot

echo "✓ Worker config applied (rebooting)"
echo ""

# Cleanup
rm -f /tmp/persistent-disk-patch.yaml

echo "================================================"
echo "✓ Configuration applied to both VMs"
echo "================================================"
echo ""
echo "The VMs are rebooting and will mount the persistent disk at $PERSISTENT_MOUNT_PATH"
echo ""
echo "Wait for VMs to come back up, then verify the mount:"
echo "  kubectl debug node/talos-worker -it --image=busybox -- sh"
echo "  # Inside debug pod:"
echo "  mount | grep $PERSISTENT_MOUNT_PATH"
echo ""
echo "Once verified, the local-path-provisioner should start working."
echo ""
