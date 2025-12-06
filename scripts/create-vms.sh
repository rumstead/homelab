#!/bin/bash
# Create and start Talos VMs using virt-install
# This script uses virt-install commands for direct VM creation

set -e

# Use kernel/initrd for network boot instead of ISO
TALOS_VERSION="v1.10.8"
KERNEL_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/vmlinuz-amd64"
INITRD_URL="https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/initramfs-amd64.xz"
KERNEL_PATH="/tmp/talos-vmlinuz"
INITRD_PATH="/tmp/talos-initramfs.xz"

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

# Check if libvirt is running
if ! systemctl is-active --quiet libvirtd; then
    echo "Starting libvirtd..."
    systemctl start libvirtd
fi

# Download Talos kernel and initrd if not present
echo "Checking Talos boot files..."
if [ ! -f "$KERNEL_PATH" ]; then
    echo "Downloading Talos kernel..."
    curl -L -o "$KERNEL_PATH" "$KERNEL_URL"
fi

if [ ! -f "$INITRD_PATH" ]; then
    echo "Downloading Talos initramfs..."
    curl -L -o "$INITRD_PATH" "$INITRD_URL"
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
    --memory 2048 \
    --disk path="$LIBVIRT_POOL_PATH/$CONTROLPLANE_NAME.qcow2,size=5,format=qcow2,bus=virtio" \
    --network network="$LIBVIRT_NETWORK,mac=52:54:00:12:34:56" \
    --boot kernel="$KERNEL_PATH",initrd="$INITRD_PATH",kernel_args='talos.platform=metal console=ttyS0' \
    --osinfo detect=on,name=linux2024 \
    --graphics vnc \
    --console pty,target_type=serial \
    --import \
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
    --network network="$LIBVIRT_NETWORK,mac=52:54:00:12:34:57" \
    --boot kernel="$KERNEL_PATH",initrd="$INITRD_PATH",kernel_args='talos.platform=metal console=ttyS0' \
    --osinfo detect=on,name=linux2024 \
    --graphics vnc \
    --console pty,target_type=serial \
    --hostdev "$GPU_PCI" \
    --import \
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


