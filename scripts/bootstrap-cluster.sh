#!/bin/bash
# Bootstrap Talos cluster
# This script configures the Talos nodes and initializes Kubernetes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TALOS_DIR="$PROJECT_DIR/talos"

CONTROLPLANE_IP="${CONTROLPLANE_IP:-192.168.1.245}"
WORKER_IP="${WORKER_IP:-192.168.1.222}"
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
if [ ! -f "$TALOS_DIR/controlplane.yaml" ]  || [ ! -f "$TALOS_DIR/worker.yaml" ]; then
    echo "ERROR: Machine configs not found in $TALOS_DIR"
    echo "Run: ./scripts/gen-talos.sh"
    exit 1
fi

# Apply machine configurations
# Note: Using --mode=reboot to apply configuration changes with VM reboot
# Persistent storage mounted from host survives the reboot cycle
# Note: Using --insecure flag for initial bootstrap (nodes don't have certs yet)
echo "Applying machine configuration to control plane..."
export TALOSCONFIG="$TALOSCONFIG_PATH"

echo "Note: Applying configs - Talos will install to disk and reboot"
echo ""

echo "Installing Talos to control plane disk..."
talosctl apply-config --insecure --nodes "$CONTROLPLANE_IP" --file "$TALOS_DIR/controlplane.yaml"

echo "Installing Talos to worker disk..."
talosctl apply-config --insecure --nodes "$WORKER_IP" --file "$TALOS_DIR/worker.yaml"

echo ""
echo "Waiting for Talos to install to disk and nodes to reboot..."
echo "This may take 3-5 minutes..."
sleep 180

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

echo ""
echo "Waiting for nodes to boot with static IPs (60 seconds)..."
sleep 60

echo ""
echo "Using static IPs (configured in machine configs):"
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

