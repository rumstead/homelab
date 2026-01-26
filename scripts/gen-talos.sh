#!/bin/bash
# Generate Talos cluster and machine configurations
# This script creates the initial Talos configs for the cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TALOS_DIR="$PROJECT_DIR/talos"

CLUSTER_NAME="acemagic-talos"
CONTROL_PLANE_IP="192.168.1.245"
WORKER_IP="192.168.1.222"
KUBERNETES_VERSION="1.34.2"
TALOS_VERSION="v1.12.2"

# Persistent storage configuration (must match create-vms.sh)
PERSISTENT_MOUNT_PATH="${PERSISTENT_MOUNT_PATH:-/var/lib/persistent}"

echo "Generating Talos configuration..."
echo "Cluster: $CLUSTER_NAME"
echo "Control Plane IP: $CONTROL_PLANE_IP"
echo "Worker IP: $WORKER_IP"

# Check if talosctl is installed
if ! command -v talosctl &> /dev/null; then
    echo "ERROR: talosctl is not installed"
    echo "Install it with: curl https://talosdev.io/install | sh"
    exit 1
fi

# Create temporary directory for generation
TEMP_DIR=$(mktemp -d)
trap 'rm -rf $TEMP_DIR' EXIT

# Generate secrets and certificates
echo "Generating secrets..."
talosctl gen secrets --output-file "$TEMP_DIR/secrets.yaml"

# Generate config for control plane
echo "Generating control plane config..."
talosctl gen config "$CLUSTER_NAME" "https://$CONTROL_PLANE_IP:6443" \
    --output-dir "$TEMP_DIR" \
    --with-secrets "$TEMP_DIR/secrets.yaml" \
    --kubernetes-version="$KUBERNETES_VERSION" \
    --talos-version="$TALOS_VERSION" \
    --force

# Extract and place configurations
echo "Extracting configurations..."
mkdir -p "$TALOS_DIR"

# Copy the main cluster config to the default talosctl location
mkdir -p "$HOME/.talos"
cp "$TEMP_DIR/talosconfig" "$HOME/.talos/config" 2>/dev/null || true

# Update talosconfig with endpoint
talosctl config endpoint "$CONTROL_PLANE_IP"
talosctl config node "$CONTROL_PLANE_IP"

# Create patch to fix install disk for virtio and disable default CNI
echo "Creating patches (install disk + disable Flannel for Cilium)..."
cat > "$TEMP_DIR/install-patch.yaml" << INSTALLEOF
machine:
  install:
    disk: /dev/vda
cluster:
  network:
    cni:
      name: none
INSTALLEOF

# Apply patches to both configs
echo "Applying patches..."
talosctl machineconfig patch "$TEMP_DIR/controlplane.yaml" \
    --patch @"$TEMP_DIR/install-patch.yaml" \
    --output "$TALOS_DIR/controlplane.yaml"

talosctl machineconfig patch "$TEMP_DIR/worker.yaml" \
    --patch @"$TEMP_DIR/install-patch.yaml" \
    --output "$TALOS_DIR/worker.yaml"

# Generate cluster.yaml for reference
cat > "$TALOS_DIR/cluster.yaml" << EOF
# Talos cluster configuration
# 
# Persistent Storage Configuration:
# - Persistent volumes are stored at: ${PERSISTENT_MOUNT_PATH}/local-path-provisioner
# - This path is mounted from the host and survives VM and host reboots
# - Local path provisioner should be configured to use this path
#
apiVersion: talos.dev/v1alpha1
kind: Cluster
metadata:
  name: $CLUSTER_NAME
spec:
  controlPlane:
    endpoint: https://$CONTROL_PLANE_IP:6443
  kubernetesVersion: "$KUBERNETES_VERSION"
  allowSchedulingOnControlPlanes: true
  talosVersion: "$TALOS_VERSION"
  network:
    dnsDomain: cluster.local
EOF

echo ""
echo "Talos configurations generated successfully!"
echo ""
echo "Generated files:"
echo "  - $TALOS_DIR/controlplane.yaml (Control Plane)"
echo "  - $TALOS_DIR/worker.yaml (Worker)"
echo "  - $TALOS_DIR/cluster.yaml (Cluster config reference)"
echo ""
echo "Network configuration:"
echo "  - Using DHCP (router assigns static IPs via MAC reservation)"
echo "  - Control Plane: 192.168.1.245 (via DHCP reservation for MAC 52:54:00:12:34:10)"
echo "  - Worker: 192.168.1.222 (via DHCP reservation for MAC 52:54:00:12:34:11)"
echo "  - Gateway: 192.168.1.1"
echo ""
echo "Persistent storage configuration:"
echo "  - Persistent disk device: /dev/vdb (attached but not yet mounted)"
echo "  - Guest mount point: $PERSISTENT_MOUNT_PATH"
echo "  - Local path provisioner should use: $PERSISTENT_MOUNT_PATH/local-path-provisioner"
echo "  ⚠ Disk mount will be added after cluster bootstrap using add-persistent-disk-mount.sh"
echo ""
echo "Next steps:"
echo "  1. Review the generated configs"
echo "  2. Run: sudo ./scripts/create-vms.sh"
echo "  3. Run: ./scripts/bootstrap-cluster.sh"
echo "  4. After cluster is up, run: ./scripts/add-persistent-disk-mount.sh"