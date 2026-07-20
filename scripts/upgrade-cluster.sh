#!/bin/bash
# Upgrade Talos OS and Kubernetes on the existing cluster
# Non-destructive: nodes upgrade in place (one at a time) and reboot.
# The cluster is NOT recreated and persistent storage is preserved.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Versions to upgrade to. Keep these in sync with scripts/gen-talos.sh
# and the talos/*.yaml machine configs.
TALOS_VERSION="${TALOS_VERSION:-v1.13.6}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.35.6}"
INSTALLER_IMAGE="${INSTALLER_IMAGE:-ghcr.io/siderolabs/installer:${TALOS_VERSION}}"

CONTROLPLANE_IP="${CONTROLPLANE_IP:-192.168.1.245}"
WORKER_IP="${WORKER_IP:-192.168.1.222}"
TALOSCONFIG_PATH="${TALOSCONFIG:-$HOME/.talos/config}"

echo "================================================"
echo "Talos / Kubernetes Cluster Upgrade"
echo "================================================"
echo ""
echo "Target Talos version:      $TALOS_VERSION"
echo "Target installer image:    $INSTALLER_IMAGE"
echo "Target Kubernetes version: $KUBERNETES_VERSION"
echo ""
echo "Control plane: $CONTROLPLANE_IP"
echo "Worker:        $WORKER_IP"
echo ""

# Check prerequisites
if ! command -v talosctl &> /dev/null; then
    echo "ERROR: talosctl is not installed"
    exit 1
fi

if [ ! -f "$TALOSCONFIG_PATH" ]; then
    echo "ERROR: talosconfig not found at $TALOSCONFIG_PATH"
    echo "Run: ./scripts/gen-talos.sh"
    exit 1
fi

export TALOSCONFIG="$TALOSCONFIG_PATH"

# Confirm before proceeding (nodes will reboot)
read -r -p "Nodes will reboot during the upgrade. Continue? [y/N] " CONFIRM
case "$CONFIRM" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Aborted."; exit 0 ;;
esac

# Upgrade Talos OS on a single node and wait for it to come back healthy.
upgrade_talos_node() {
    local node="$1"
    local role="$2"

    echo ""
    echo "------------------------------------------------"
    echo "Upgrading Talos on $role ($node) -> $TALOS_VERSION"
    echo "------------------------------------------------"

    # --preserve keeps ephemeral data; safe for single-node control plane.
    # talosctl blocks until the node is healthy again after the reboot.
    talosctl upgrade \
        --nodes "$node" \
        --image "$INSTALLER_IMAGE" \
        --preserve \
        --wait

    echo "✓ $role is back online on Talos $TALOS_VERSION"
}

# Upgrade control plane first, then the worker (one node at a time).
upgrade_talos_node "$CONTROLPLANE_IP" "control plane"
upgrade_talos_node "$WORKER_IP" "worker"

# Upgrade Kubernetes (control plane components + kubelets) via Talos.
echo ""
echo "------------------------------------------------"
echo "Upgrading Kubernetes -> $KUBERNETES_VERSION"
echo "------------------------------------------------"
talosctl upgrade-k8s \
    --nodes "$CONTROLPLANE_IP" \
    --to "$KUBERNETES_VERSION"

echo ""
echo "================================================"
echo "Upgrade complete"
echo "================================================"
echo "Talos:      $TALOS_VERSION"
echo "Kubernetes: $KUBERNETES_VERSION"
echo ""
echo "Verify with:"
echo "  talosctl -n $CONTROLPLANE_IP version"
echo "  kubectl get nodes -o wide"
