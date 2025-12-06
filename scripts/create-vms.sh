#!/bin/bash
# Create and start Talos VMs using virt-install
# This script uses virt-install commands for direct VM creation

set -e

ISO_PATH="/home/rumstead/Downloads/metal-amd64.iso"
LIBVIRT_POOL_PATH="/var/lib/libvirt/images"
LIBVIRT_NETWORK="default"

CONTROLPLANE_NAME="acemagic-talos-controlplane"
WORKER_NAME="acemagic-talos-worker"

echo "================================================"
echo "Talos VM Creation Script (virt-install)"
echo "================================================"
echo ""
echo "VMs to create:"
echo "  - $CONTROLPLANE_NAME (2 CPU, 2GB RAM, 5GB disk)"
echo "  - $WORKER_NAME (6 CPU, 10GB RAM, 25GB disk, GPU passthrough)"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

# Check if ISO exists
if [ ! -f "$ISO_PATH" ]; then
    echo "ERROR: Talos ISO not found at $ISO_PATH"
    echo "Download it from: https://www.talos.dev/latest/talos-guides/install/bare-metal-platforms/"
    exit 1
fi

# Check if libvirt is running
if ! systemctl is-active --quiet libvirtd; then
    echo "Starting libvirtd..."
    systemctl start libvirtd
fi

# Copy ISO to libvirt pool for accessibility
echo "Checking ISO accessibility..."
ISO_POOL_PATH="$LIBVIRT_POOL_PATH/metal-amd64.iso"
if [ ! -f "$ISO_POOL_PATH" ]; then
    echo "Copying ISO to libvirt pool..."
    cp "$ISO_PATH" "$ISO_POOL_PATH"
    chmod 644 "$ISO_POOL_PATH"
else
    echo "ISO already in libvirt pool"
fi
ISO_PATH="$ISO_POOL_PATH"

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
    --memory 2048 \
    --disk path="$LIBVIRT_POOL_PATH/$CONTROLPLANE_NAME.qcow2,size=5,format=qcow2,bus=virtio" \
    --cdrom "$ISO_PATH" \
    --network network="$LIBVIRT_NETWORK,mac=52:54:00:12:34:56" \
    --osinfo detect=on,name=linux2024 \
    --graphics vnc \
    --console pty,target_type=serial \
    --boot hd,menu=off \
    --accelerate \
    --noautoconsole

echo "✓ Control Plane VM created!"
echo ""
echo "Creating Worker VM (with GPU passthrough)..."
echo ""
echo "NOTE: Update the GPU PCI address before running!"
echo "Find your GPU with: lspci | grep -i nvidia/amd/intel"
echo "Your AMD Barcelo GPU detected at: 0000:03:00.0"
echo ""
read -p "Enter GPU PCI address (default: 0000:03:00.0): " GPU_PCI
GPU_PCI="${GPU_PCI:-0000:03:00.0}"

virt-install \
    --name "$WORKER_NAME" \
    --vcpus 6 \
    --memory 10240 \
    --disk path="$LIBVIRT_POOL_PATH/$WORKER_NAME.qcow2,size=25,format=qcow2,bus=virtio" \
    --cdrom "$ISO_PATH" \
    --network network="$LIBVIRT_NETWORK,mac=52:54:00:12:34:57" \
    --osinfo detect=on,name=linux2024 \
    --graphics vnc \
    --console pty,target_type=serial \
    --boot hd,menu=off \
    --accelerate \
    --hostdev "$GPU_PCI" \
    --noautoconsole

echo "✓ Worker VM created!"
echo ""
echo "================================================"
echo "✓ VMs created and started successfully!"
echo "================================================"
echo ""
echo "VM Details:"
virsh list --name | grep acemagic
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
echo "================================================"
echo "Exporting VM XML definitions..."
echo "================================================"
virsh dumpxml "$CONTROLPLANE_NAME" > "$LIBVIRT_POOL_PATH/../controlplane.xml" 2>/dev/null || true
virsh dumpxml "$WORKER_NAME" > "$LIBVIRT_POOL_PATH/../worker.xml" 2>/dev/null || true
echo "✓ XML definitions exported to:"
echo "  - $LIBVIRT_POOL_PATH/../controlplane.xml"
echo "  - $LIBVIRT_POOL_PATH/../worker.xml"
echo ""
echo "You can now backup these or use them to recreate VMs later"

