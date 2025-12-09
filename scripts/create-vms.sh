#!/bin/bash
# Create and start Talos VMs using virt-install
# This script uses virt-install commands for direct VM creation

set -e

TALOS_VERSION="v1.10.8"
ISO_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/metal-amd64.iso"
ISO_PATH="/tmp/talos-metal-amd64.iso"

LIBVIRT_POOL_PATH="/var/lib/libvirt/images"
BRIDGE_NAME="br0"
PHYSICAL_INTERFACE="enp2s0"

CONTROLPLANE_NAME="talos-controlplane"
WORKER_NAME="talos-worker"

echo "================================================"
echo "Talos VM Creation Script (virt-install)"
echo "================================================"
echo ""
echo "VMs to create:"
echo "  - $CONTROLPLANE_NAME (2 CPU, 5GB RAM, 10GB disk)"
echo "  - $WORKER_NAME (6 CPU, 10GB RAM, 25GB disk, GPU passthrough)"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Check if libvirt is running
if ! systemctl is-active --quiet libvirtd; then
    echo "Starting libvirtd..."
    systemctl start libvirtd
fi

# Create bridge network if it doesn't exist
echo "Checking bridge network..."
if ! ip link show "$BRIDGE_NAME" &>/dev/null; then
    echo "Creating bridge $BRIDGE_NAME..."
    ip link add name "$BRIDGE_NAME" type bridge
    ip link set "$PHYSICAL_INTERFACE" master "$BRIDGE_NAME"
    
    # Transfer IP from physical interface to bridge
    PHYS_IP=$(ip -4 addr show "$PHYSICAL_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}/\d+' || true)
    if [ -n "$PHYS_IP" ]; then
        ip addr del "$PHYS_IP" dev "$PHYSICAL_INTERFACE" || true
        ip addr add "$PHYS_IP" dev "$BRIDGE_NAME"
    fi
    
    ip link set "$BRIDGE_NAME" up
    ip link set "$PHYSICAL_INTERFACE" up
    
    echo "Bridge created and configured"
else
    echo "Bridge $BRIDGE_NAME already exists"
fi

# Download Talos ISO if not present
echo "Checking Talos ISO..."
if [ ! -f "$ISO_PATH" ]; then
    echo "Downloading Talos ISO..."
    curl -L -o "$ISO_PATH" "$ISO_URL"
fi

# Clean up existing VMs if they exist
echo "Checking for existing VMs..."
if virsh list --all --name | grep -q "^$CONTROLPLANE_NAME$"; then
    echo "Removing existing Control Plane VM..."
    virsh destroy "$CONTROLPLANE_NAME" 2>/dev/null || true
    virsh undefine "$CONTROLPLANE_NAME" --remove-all-storage 2>/dev/null || true
fi

if virsh list --all --name | grep -q "^$WORKER_NAME$"; then
    echo "Removing existing Worker VM..."
    virsh destroy "$WORKER_NAME" 2>/dev/null || true
    virsh undefine "$WORKER_NAME" --remove-all-storage 2>/dev/null || true
fi

echo "Creating Control Plane VM..."
virt-install \
    --name "$CONTROLPLANE_NAME" \
    --vcpus 2 \
    --memory 5120 \
    --disk path="$LIBVIRT_POOL_PATH/$CONTROLPLANE_NAME.qcow2,size=10,format=qcow2,bus=virtio" \
    --cdrom "$ISO_PATH" \
    --network bridge="$BRIDGE_NAME",mac=52:54:00:12:34:56,model=virtio \
    --osinfo detect=on,name=linux2024 \
    --graphics vnc \
    --console pty,target_type=serial \
    --boot hd,cdrom \
    --noautoconsole

echo "✓ Control Plane VM created!"
echo ""
echo "Creating Worker VM (with GPU passthrough)..."
echo ""
echo "NOTE: Update the GPU PCI address before running!"
echo "Find your GPU with: lspci | grep -i gpa"
echo ""
read -p "Enter GPU PCI address (default: 0000:03:00.0): " GPU_PCI
GPU_PCI="${GPU_PCI:-0000:03:00.0}"

virt-install \
    --name "$WORKER_NAME" \
    --vcpus 6 \
    --memory 10240 \
    --disk path="$LIBVIRT_POOL_PATH/$WORKER_NAME.qcow2,size=25,format=qcow2,bus=virtio" \
    --cdrom "$ISO_PATH" \
    --network bridge="$BRIDGE_NAME",mac=52:54:00:12:34:57,model=virtio \
    --osinfo detect=on,name=linux2024 \
    --graphics vnc \
    --console pty,target_type=serial \
    --boot hd,cdrom \
    --hostdev "$GPU_PCI" \
    --noautoconsole

echo "✓ Worker VM created!"
echo ""
echo "================================================"
echo "✓ VMs created and started successfully!"
echo "================================================"
echo ""
echo "VM Details:"
virsh list --name
echo ""
echo "To access VM console:"
echo "  virsh console $CONTROLPLANE_NAME"
echo "  virsh console $WORKER_NAME"
echo ""
echo "To monitor boot:"
echo "  watch virsh domstate $CONTROLPLANE_NAME"
echo "  watch virsh domstate $WORKER_NAME"
echo ""
echo "Expected boot sequence:"
echo "  1. VMs start with Talos ISO"
echo "  2. Talos installer boots"
echo "  3. Once ready, IPs will be assigned (check with 'virsh domifaddr <vm-name>')"
echo ""
echo "Next step:"
echo "  Run: ./scripts/bootstrap-cluster.sh"
echo ""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
VMS_DIR="$PROJECT_DIR/vms"

echo "================================================"
echo "Exporting VM XML definitions..."
echo "================================================"
mkdir -p "$VMS_DIR"
virsh dumpxml "$CONTROLPLANE_NAME" > "$VMS_DIR/controlplane.xml" 2>/dev/null || true
virsh dumpxml "$WORKER_NAME" > "$VMS_DIR/worker.xml" 2>/dev/null || true
echo "✓ XML definitions exported to:"
echo "  - $VMS_DIR/controlplane.xml"
echo "  - $VMS_DIR/worker.xml"
echo ""


