#!/bin/bash
# Install a lightweight XFCE desktop environment on the Ubuntu host
# Provides GUI access both locally (at the machine) and remotely via:
#   - xrdp (RDP on port 3389 — works from any RDP client, including Chromebook)
#   - SSH X11 forwarding (ssh -X user@acemagic)

set -e

echo "================================================"
echo "XFCE Desktop + Remote Access Setup"
echo "================================================"
echo ""
echo "This will install:"
echo "  - XFCE4 desktop environment (lightweight)"
echo "  - xrdp for remote desktop access (port 3389)"
echo "  - Google Chrome web browser"
echo "  - Basic utilities (file manager, terminal, text editor)"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "Updating package lists..."
apt-get update

# Install XFCE desktop (minimal, no bloat)
echo ""
echo "Installing XFCE desktop environment..."
apt-get install -y \
    xfce4 \
    xfce4-terminal \
    xfce4-whiskermenu-plugin \
    thunar \
    mousepad \
    xfce4-taskmanager \
    xfce4-screenshooter

# Install display manager
echo ""
echo "Installing LightDM display manager..."
apt-get install -y lightdm lightdm-gtk-greeter

# Install Google Chrome
echo ""
echo "Installing Google Chrome..."
if ! command -v google-chrome &> /dev/null; then
    curl -fsSL -o /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y /tmp/google-chrome.deb
    rm -f /tmp/google-chrome.deb
else
    echo "✓ Google Chrome already installed"
fi

# Install xrdp for remote desktop
echo ""
echo "Installing xrdp..."
apt-get install -y xrdp

# Configure xrdp to use XFCE
echo ""
echo "Configuring xrdp to use XFCE session..."
cat > /etc/xrdp/startwm.sh << 'XRDPEOF'
#!/bin/sh
if [ -r /etc/default/locale ]; then
    . /etc/default/locale
    export LANG LANGUAGE
fi

# Start XFCE session
exec startxfce4
XRDPEOF
chmod +x /etc/xrdp/startwm.sh

# Add xrdp user to ssl-cert group (needed for TLS)
usermod -a -G ssl-cert xrdp

# Configure SSH X11 forwarding
echo ""
echo "Configuring SSH X11 forwarding..."
SSHD_CONFIG="/etc/ssh/sshd_config"

# Enable X11Forwarding if not already set
if grep -q "^X11Forwarding" "$SSHD_CONFIG"; then
    sed -i 's/^X11Forwarding.*/X11Forwarding yes/' "$SSHD_CONFIG"
else
    echo "X11Forwarding yes" >> "$SSHD_CONFIG"
fi

# Enable X11UseLocalhost no (allows forwarding to remote displays)
if grep -q "^X11UseLocalhost" "$SSHD_CONFIG"; then
    sed -i 's/^X11UseLocalhost.*/X11UseLocalhost no/' "$SSHD_CONFIG"
else
    echo "X11UseLocalhost no" >> "$SSHD_CONFIG"
fi

# Install xauth (required for X11 forwarding)
apt-get install -y xauth

# Enable and start services
echo ""
echo "Enabling services..."
systemctl enable lightdm
systemctl enable xrdp
systemctl restart xrdp
systemctl restart ssh

# Set default target to graphical (so desktop starts on boot)
systemctl set-default graphical.target

echo ""
echo "================================================"
echo "✓ Desktop environment installed successfully!"
echo "================================================"
echo ""
echo "Access methods:"
echo ""
echo "  1. LOCAL (at the machine):"
echo "     - Reboot or run: sudo systemctl start lightdm"
echo "     - Login with your user credentials at the XFCE desktop"
echo ""
echo "  2. REMOTE via RDP (from Chromebook or any device):"
echo "     - Connect to: 192.168.1.234:3389"
echo "     - Use any RDP client (Chrome Remote Desktop, Remmina, etc.)"
echo "     - Login with your Linux user credentials"
echo ""
echo "  3. REMOTE via SSH X11 forwarding:"
echo "     - Connect: ssh -X $(logname 2>/dev/null || echo 'user')@192.168.1.234"
echo "     - Launch apps: google-chrome &"
echo "     - Note: Requires X11 server on the client side"
echo ""
echo "Installed components:"
echo "  - XFCE4 desktop environment"
echo "  - LightDM display manager"
echo "  - Google Chrome web browser"
echo "  - xrdp (port 3389)"
echo "  - X11 forwarding enabled in SSH"
