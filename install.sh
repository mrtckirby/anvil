#!/bin/bash
# Anvil Installation Script
# This script sets up a fresh Ubuntu server as an Anvil community server

set -e

echo "=================================="
echo "  Anvil Community Server Setup"
echo "=================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: This script must be run as root"
    echo "Please run: sudo ./install.sh"
    exit 1
fi

echo "[1/5] Installing required packages..."
apt-get update -qq
apt-get install -y \
    openssh-server \
    lighttpd \
    vsftpd \
    libpam-modules \
    coreutils \
    sed \
    grep

echo "[2/5] Configuring Lighttpd for user directories..."
lighttpd-enable-mod userdir
cat << 'EOF' > /etc/lighttpd/conf-available/15-userdir.conf
userdir.path = "public_html"
userdir.exclude-user = ("root")
EOF
systemctl restart lighttpd

echo "[3/5] Installing registration engine..."
cp ssh-autocreate-user.sh /usr/local/bin/ssh-autocreate-user.sh
chmod 755 /usr/local/bin/ssh-autocreate-user.sh

echo "[4/5] Running system infrastructure setup..."
chmod +x setup.sh
./setup.sh

echo "[5/5] Verifying installation..."
# Check if services are running
systemctl is-active --quiet ssh && echo "✓ SSH server running" || echo "✗ SSH server failed"
systemctl is-active --quiet lighttpd && echo "✓ Web server running" || echo "✗ Web server failed"
systemctl is-active --quiet vsftpd && echo "✓ FTP server running" || echo "✗ FTP server failed"

# Check if PAM hook is installed
if grep -q "ssh-autocreate-user.sh" /etc/pam.d/common-auth; then
    echo "✓ PAM auto-registration hook installed"
else
    echo "✗ PAM hook installation failed"
fi

echo ""
echo "=================================="
echo "  Installation Complete!"
echo "=================================="
echo ""
echo "Your Anvil server is ready!"
echo ""
echo "Users can now SSH to this server with any username."
echo "On first connection, an account will be auto-created."
echo "Default password = username (must be changed on first login)"
echo ""
echo "Community directory: http://$(hostname -I | awk '{print $1}')"
echo "User pages: http://$(hostname -I | awk '{print $1}')/~username/"
echo ""