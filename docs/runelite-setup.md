# RuneLite (OSRS) Setup on Acemagic Host

## Prerequisites

- Desktop environment installed (`scripts/install-desktop.sh`)
- RuneLite AppImage downloaded (e.g., `RuneLite.AppImage`)

## 1. Install dependencies

```bash
# AppImage support (FUSE is required to run AppImages)
sudo apt-get install -y libfuse2

# AMD GPU drivers (Mesa — for Radeon Vega on the Ryzen 7 7730U)
sudo apt-get install -y mesa-utils mesa-vulkan-drivers libgl1-mesa-dri

# Audio support (for game sounds over RDP/local)
sudo apt-get install -y pulseaudio pavucontrol
```

## 2. Make the AppImage executable

```bash
chmod +x ~/Downloads/RuneLite.AppImage
# Or wherever you downloaded it — adjust the path
```

## 3. Run RuneLite

```bash
# Launch directly
~/Downloads/RuneLite.AppImage

# Or if you get GPU errors, force software rendering:
LIBGL_ALWAYS_SOFTWARE=1 ~/Downloads/RuneLite.AppImage
```

Verify the iGPU is working:
```bash
glxinfo | grep "OpenGL renderer"
# Should show something like: AMD Radeon Graphics (radeonsi, ...)
# If you see "llvmpipe" instead, see the GPU Troubleshooting section below
```

## 4. GPU Troubleshooting (llvmpipe / software rendering)

If `glxinfo` shows `llvmpipe` instead of AMD Radeon, the integrated GPU isn't
being used. This is common when the discrete GPU is passed through to a VM.

### Diagnose

```bash
# Check what GPUs the system sees
lspci | grep -i vga

# Check which kernel driver is bound to each GPU
lspci -k | grep -A3 -i vga

# Check if amdgpu module is loaded
lsmod | grep -E 'amdgpu|vfio'

# Check if the iGPU has a /dev/dri device
ls -la /dev/dri/
```

### Common causes and fixes

**Cause 1: amdgpu driver not loaded for the iGPU**
```bash
sudo modprobe amdgpu
# Then re-check:
glxinfo | grep "OpenGL renderer"
```

To make it persist across reboots, ensure `amdgpu` is not blacklisted:
```bash
# Check for blacklists
grep -r amdgpu /etc/modprobe.d/
# Remove any lines that blacklist amdgpu for the iGPU
```

**Cause 2: iGPU is bound to vfio-pci (grabbed for passthrough)**
```bash
# Check if vfio has grabbed the iGPU
lspci -k | grep -A3 -i vga
# If the iGPU line shows "Kernel driver in use: vfio-pci", it's been grabbed

# Find the iGPU PCI address (NOT the discrete GPU at 0000:03:00.0)
lspci | grep -i vga
# The iGPU is typically at something like 0000:06:00.0 or 0000:00:02.0

# Check your vfio config to see what's being passed through
cat /etc/modprobe.d/vfio.conf
# Only the discrete GPU (0000:03:00.0) should be listed, not the iGPU
```

If the iGPU is bound to vfio-pci, remove its PCI ID from `/etc/modprobe.d/vfio.conf`
and rebuild initramfs:
```bash
sudo update-initramfs -u
sudo reboot
```

**Cause 3: iGPU disabled in BIOS**

Enter BIOS (F2/Del on boot) and ensure the integrated GPU is enabled.
Look for settings like "iGPU Multi-Monitor" or "Integrated Graphics" — enable it.

**Cause 4: Missing firmware**
```bash
sudo apt-get install -y firmware-amd-graphics linux-firmware
sudo reboot
```

### If you can't get the iGPU working

RuneLite still works with software rendering (llvmpipe). To optimize it:
- In RuneLite: Settings → GPU plugin → disable it (use the software renderer)
- Lower game resolution and disable anti-aliasing
- This is playable for OSRS since it's not graphically demanding

## 5. Create a desktop shortcut (optional)

```bash
mkdir -p ~/.local/share/applications

cat > ~/.local/share/applications/runelite.desktop << 'EOF'
[Desktop Entry]
Name=RuneLite
Comment=Old School RuneScape Client
Exec=/home/rjumstead/RuneLite.AppImage
Icon=runelite
Terminal=false
Type=Application
Categories=Game;
EOF

# Move the AppImage to a permanent location
mv ~/Downloads/RuneLite.AppImage ~/RuneLite.AppImage
```

The shortcut will appear in the XFCE application menu under "Games".

## 6. Launching from remote sessions

### Local (at the machine)
Just double-click the AppImage or use the desktop shortcut.

### Via RDP from Chromebook (Microsoft Remote Desktop)

1. Install **Microsoft Remote Desktop** from the Play Store on your Chromebook
2. Open the app → tap `+` → **Add PC**
3. Enter `192.168.1.234` as the PC name
4. Tap **Add user account** and enter your credentials (`rumstead` / your password)
5. Under **Display**, set resolution to match your Chromebook screen
6. Save and tap the connection to launch

The host already has xrdp running on port `3389`. Once connected, launch
RuneLite from the XFCE desktop or terminal.

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `AppImages require FUSE to run` | `sudo apt-get install -y libfuse2` |
| Black screen / GPU errors | Run with `LIBGL_ALWAYS_SOFTWARE=1` prefix |
| No sound | `pulseaudio --start` then relaunch RuneLite |
| AppImage won't launch at all | Extract and run directly: `./RuneLite.AppImage --appimage-extract && ./squashfs-root/AppRun` |
| Laggy via RDP | In RuneLite: disable GPU plugin, lower resolution |
