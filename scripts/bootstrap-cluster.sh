#!/bin/bash
# Bootstrap Talos cluster
# This script configures the Talos nodes and initializes Kubernetes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TALOS_DIR="$PROJECT_DIR/talos"

CONTROLPLANE_IP="${CONTROLPLANE_IP:-192.168.1.10}"
WORKER_IP="${WORKER_IP:-192.168.1.11}"
TALOSCONFIG_PATH="${TALOSCONFIG:-$HOME/.talos/config}"

echo "================================================"
echo "Talos Cluster Bootstrap"
echo "================================================"
echo ""

# Check if talosctl is installed
if ! command -v talosctl &> /dev/null; then
    echo "ERROR: talosctl is not installed"
    echo "Install it with: curl https://talosdev.io/install | sh"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl is not installed"
    exit 1
fi

# Check if talosconfig exists
if [ ! -f "$TALOSCONFIG_PATH" ]; then
    echo "ERROR: talosconfig not found at $TALOSCONFIG_PATH"
    echo "Run: ./scripts/gen-talos.sh"
    exit 1
fi

# Check if machine configs exist
if [ ! -f "$TALOS_DIR/controlplane.yaml" ] || [ ! -f "$TALOS_DIR/worker.yaml" ]; then
    echo "ERROR: Machine configs not found in $TALOS_DIR"
    echo "Run: ./scripts/gen-talos.sh"
    exit 1
fi

# Apply machine configurations
# Note: Using --mode=reboot to apply configuration changes with VM reboot
# Persistent storage mounted from host survives the reboot cycle
echo "Applying machine configuration to control plane..."
export TALOSCONFIG="$TALOSCONFIG_PATH"

# First check if nodes are reachable
echo "Checking if control plane is reachable at $CONTROLPLANE_IP..."
if ! ping -c 1 -W 2 "$CONTROLPLANE_IP" &>/dev/null; then
    echo "ERROR: Cannot reach control plane at $CONTROLPLANE_IP"
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check if VMs are running:"
    echo "   sudo virsh list --all"
    echo ""
    echo "2. Check VM IP addresses:"
    echo "   sudo virsh domifaddr talos-controlplane"
    echo "   sudo virsh domifaddr talos-worker"
    echo ""
    echo "3. Check bridge network:"
    echo "   ip link show br0"
    echo "   bridge link show"
    echo ""
    echo "4. If VMs have no IP, check if they booted correctly:"
    echo "   sudo virsh console talos-controlplane"
    echo ""
    exit 1
fi

echo "Checking if worker is reachable at $WORKER_IP..."
if ! ping -c 1 -W 2 "$WORKER_IP" &>/dev/null; then
    echo "WARNING: Cannot reach worker at $WORKER_IP"
    echo "Continuing anyway, but worker might not join..."
fi

talosctl apply-config --insecure --nodes "$CONTROLPLANE_IP" --mode=reboot --file "$TALOS_DIR/controlplane.yaml"

echo "Applying machine configuration to worker..."
talosctl apply-config --insecure --nodes "$WORKER_IP" --mode=reboot --file "$TALOS_DIR/worker.yaml"

echo ""
echo "Waiting for nodes to apply configuration and reboot..."
echo "This may take 2-3 minutes..."
sleep 60

# Check if VMs are running and start them if needed
echo "Checking VM states..."
CP_STATE=$(sudo virsh domstate talos-controlplane 2>/dev/null || echo "not-found")
WORKER_STATE=$(sudo virsh domstate talos-worker 2>/dev/null || echo "not-found")

if [ "$CP_STATE" = "shut off" ]; then
    echo "Starting control plane VM..."
    sudo virsh start talos-controlplane
    sleep 10
fi

if [ "$WORKER_STATE" = "shut off" ]; then
    echo "Starting worker VM..."
    sudo virsh start talos-worker
    sleep 10
fi

# Detect actual VM IP addresses
echo "Detecting VM IP addresses..."
echo "Waiting for DHCP leases (30 seconds)..."
sleep 30

echo ""
echo "Checking control plane IP..."
CP_IP_DETECTED=$(sudo virsh domifaddr talos-controlplane 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -n1 || echo "")
if [ -n "$CP_IP_DETECTED" ]; then
    echo "  Detected: $CP_IP_DETECTED"
    if [ "$CP_IP_DETECTED" != "$CONTROLPLANE_IP" ]; then
        echo "  WARNING: Detected IP differs from expected ($CONTROLPLANE_IP)"
        echo "  Using detected IP: $CP_IP_DETECTED"
        CONTROLPLANE_IP="$CP_IP_DETECTED"
    fi
else
    echo "  WARNING: Could not detect IP, using configured: $CONTROLPLANE_IP"
fi

echo ""
echo "Checking worker IP..."
WORKER_IP_DETECTED=$(sudo virsh domifaddr talos-worker 2>/dev/null | grep -oP '(\d+\.){3}\d+' | head -n1 || echo "")
if [ -n "$WORKER_IP_DETECTED" ]; then
    echo "  Detected: $WORKER_IP_DETECTED"
    if [ "$WORKER_IP_DETECTED" != "$WORKER_IP" ]; then
        echo "  WARNING: Detected IP differs from expected ($WORKER_IP)"
        echo "  Using detected IP: $WORKER_IP_DETECTED"
        WORKER_IP="$WORKER_IP_DETECTED"
    fi
else
    echo "  WARNING: Could not detect IP, using configured: $WORKER_IP"
fi

echo ""
echo "Using IPs:"
echo "  Control Plane: $CONTROLPLANE_IP"
echo "  Worker: $WORKER_IP"
echo ""

# Wait for nodes to be ready
echo "Waiting for control plane node to be ready..."
RETRIES=0
MAX_RETRIES=120

while [ $RETRIES -lt $MAX_RETRIES ]; do
    if talosctl -n "$CONTROLPLANE_IP" service etcd status &>/dev/null; then
        echo "✓ Control plane is ready!"
        break
    fi
    if [ $((RETRIES % 6)) -eq 0 ]; then
        echo "  Waiting... ($((RETRIES+1))/$MAX_RETRIES)"
    fi
    sleep 5
    RETRIES=$((RETRIES + 1))
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    echo "ERROR: Control plane failed to become ready"
    echo ""
    echo "Debugging:"
    echo "  Check VM console: virsh console talos-controlplane"
    echo "  Check VM IP: virsh domifaddr talos-controlplane"
    exit 1
fi

# Configure talosctl
echo "Configuring talosctl context..."
export TALOSCONFIG="$TALOSCONFIG_PATH"

# Check if talosconfig exists
if [ ! -f "$TALOSCONFIG" ]; then
    echo "ERROR: $TALOSCONFIG not found"
    echo "Run: ./scripts/gen-talos.sh"
    exit 1
fi

# Set talosctl endpoints
talosctl config endpoint "$CONTROLPLANE_IP"
talosctl config node "$CONTROLPLANE_IP"

echo "Bootstrapping cluster..."
talosctl bootstrap -n "$CONTROLPLANE_IP"

echo ""
echo "Waiting for Kubernetes API to be ready..."
RETRIES=0
MAX_RETRIES=60

while [ $RETRIES -lt $MAX_RETRIES ]; do
    if talosctl -n "$CONTROLPLANE_IP" kubeconfig "$PROJECT_DIR/kubeconfig" 2>/dev/null; then
        echo "✓ Kubernetes API is ready!"
        break
    fi
    echo "  Waiting... ($((RETRIES+1))/$MAX_RETRIES)"
    sleep 5
    RETRIES=$((RETRIES + 1))
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    echo "WARNING: Kubernetes API not ready yet"
fi

# Generate kubeconfig
echo "Generating kubeconfig..."
talosctl -n "$CONTROLPLANE_IP" kubeconfig

# Wait for worker node to be discoverable
echo ""
echo "Waiting for worker node..."
RETRIES=0
MAX_RETRIES=60

while [ $RETRIES -lt $MAX_RETRIES ]; do
    if ping -c 1 "$WORKER_IP" &>/dev/null; then
        echo "✓ Worker node is reachable!"
        break
    fi
    echo "  Waiting... ($((RETRIES+1))/$MAX_RETRIES)"
    sleep 5
    RETRIES=$((RETRIES + 1))
done

if [ $RETRIES -eq $MAX_RETRIES ]; then
    echo "WARNING: Worker node not reachable, continuing anyway..."
fi

# Set kubeconfig for kubectl
export KUBECONFIG="$PROJECT_DIR/kubeconfig"

# Wait for nodes to appear in kubectl
echo ""
echo "Waiting for nodes to appear in Kubernetes..."
RETRIES=0
MAX_RETRIES=60

while [ $RETRIES -lt $MAX_RETRIES ]; do
    NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l 2>/dev/null || true)
    NODES=${NODES:-0}
    if [ "$NODES" -ge 1 ]; then
        echo "✓ Nodes are joining the cluster!"
        break
    fi
    echo "  Waiting for nodes... ($((RETRIES+1))/$MAX_RETRIES)"
    sleep 5
    RETRIES=$((RETRIES + 1))
done

echo ""
echo "✓ Bootstrap complete!"
echo ""
echo "Cluster Status:"
kubectl get nodes
echo ""
echo "To use kubectl:"
echo "  export KUBECONFIG=$PROJECT_DIR/kubeconfig"
echo "  kubectl get pods --all-namespaces"
echo ""
echo "To access Talos nodes:"
echo "  talosctl -n $CONTROLPLANE_IP get nodes"
echo "  talosctl -n $WORKER_IP get nodes"
echo ""
echo "To access node dashboard:"
echo "  talosctl -n $CONTROLPLANE_IP dashboard"
echo "  talosctl -n $WORKER_IP dashboard"

