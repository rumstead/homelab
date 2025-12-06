#!/bin/bash
# Generate Talos cluster and machine configurations
# This script creates the initial Talos configs for the cluster

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TALOS_DIR="$PROJECT_DIR/talos"

CLUSTER_NAME="acemagic-talos"
CONTROL_PLANE_IP="192.168.1.10"
WORKER_IP="192.168.1.11"
KUBERNETES_VERSION="1.34.2"
TALOS_VERSION="v1.10.8"

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
trap "rm -rf $TEMP_DIR" EXIT

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

# Extract control plane config
cp "$TEMP_DIR/controlplane.yaml" "$TALOS_DIR/controlplane.yaml"

# Patch controlplane config with static IP, correct disk, and cert SANs
talosctl machineconfig patch "$TALOS_DIR/controlplane.yaml" \
  --patch '[{"op": "replace", "path": "/machine/network", "value": {"hostname": "talos-controlplane", "interfaces": [{"interface": "eth0", "dhcp": true}]}}, {"op": "replace", "path": "/machine/install/disk", "value": "/dev/vda"}, {"op": "add", "path": "/machine/certSANs", "value": ["'$CONTROL_PLANE_IP'"]}]' \
  --output "$TALOS_DIR/controlplane.yaml"

# Extract worker config
cp "$TEMP_DIR/worker.yaml" "$TALOS_DIR/worker.yaml"

# Patch worker config with static IP, correct disk, and cert SANs
talosctl machineconfig patch "$TALOS_DIR/worker.yaml" \
  --patch '[{"op": "replace", "path": "/machine/network", "value": {"hostname": "talos-worker", "interfaces": [{"interface": "eth0", "dhcp": true}]}}, {"op": "replace", "path": "/machine/install/disk", "value": "/dev/vda"}, {"op": "add", "path": "/machine/certSANs", "value": ["'$WORKER_IP'"]}]' \
  --output "$TALOS_DIR/worker.yaml"

# Generate cluster.yaml for reference
cat > "$TALOS_DIR/cluster.yaml" << EOF
# Talos cluster configuration
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
echo "Next steps:"
echo "  1. Review the generated configs"
echo "  2. Run: sudo ./scripts/create-vms.sh"
echo "  3. Run: ./scripts/bootstrap-cluster.sh"

