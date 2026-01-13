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

echo "[1/6] Installing required packages..."
apt-get update -qq
apt-get install -y \
    openssh-server \
    lighttpd \
    vsftpd \
    libpam-modules \
    coreutils \
    sed \
    grep \
    quota \
    openssl

echo "[2/6] Configuring Lighttpd for user directories..."
# Disable the module first to clean up any existing config
lighttpd-disable-mod userdir 2>/dev/null || true
# Enable the module (creates 10-userdir.conf by default)
lighttpd-enable-mod userdir
# Overwrite THE DEFAULT FILE (10-userdir.conf, not 15!)
cat << 'EOF' > /etc/lighttpd/conf-available/10-userdir.conf
userdir.path = "public_html"
userdir.exclude-user = ("root")
EOF

echo "[3/6] Checking user quota configuration..."

# Function to check if quotas are enabled
check_quotas() {
    if quotaon -p / 2>/dev/null | grep -q "user quota on"; then
        return 0  # Quotas enabled
    else
        return 1  # Quotas not enabled
    fi
}

# Function to enable quotas
enable_quotas() {
    local quota_mb=$1
    
    echo "  → Installing quota support..."
    
    # Find the root filesystem device
    ROOT_DEV=$(df / | tail -1 | awk '{print $1}')
    
    # Add usrquota to fstab if not already present
    if ! grep -q "usrquota" /etc/fstab; then
        echo "  → Updating /etc/fstab with quota options..."
        # Backup fstab
        cp /etc/fstab /etc/fstab.backup
        # Add usrquota option to root filesystem
        sed -i "s|\(^[^#].*[[:space:]]/[[:space:]].*[[:space:]]defaults\)|\1,usrquota|" /etc/fstab
    fi
    
    echo "  → Remounting filesystem with quota support..."
    mount -o remount /
    
    echo "  → Creating quota files..."
    quotacheck -cum /
    
    echo "  → Enabling quotas..."
    quotaon /
    
    # Set default quota for new users
    if [ "$quota_mb" -gt 0 ]; then
        echo "  → Setting default quota to ${quota_mb}MB per user..."
        # Create a temporary user to set prototype quota
        useradd -M quotaproto 2>/dev/null || true
        setquota -u quotaproto $((quota_mb * 1024)) $((quota_mb * 1024 + 10240)) 0 0 /
        # Make this the default for new users
        edquota -p quotaproto -u quotaproto
        userdel quotaproto 2>/dev/null || true
        
        # Store quota size for the registration script
        echo "$quota_mb" > /etc/anvil-quota-mb
    fi
    
    echo "  ✓ Quotas enabled successfully!"
}

if ! check_quotas; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  USER QUOTAS ARE NOT ENABLED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "User quotas limit disk space per user, preventing"
    echo "any single user from filling up the server."
    echo ""
    echo "Would you like to enable user quotas? (y/n)"
    read -r enable_quota
    
    if [[ "$enable_quota" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enter quota size per user in MB (e.g., 100, 500, 1000)"
        echo "Or enter 0 to enable quotas without limits:"
        read -r quota_size
        
        # Validate input
        if ! [[ "$quota_size" =~ ^[0-9]+$ ]]; then
            echo "Invalid input. Skipping quota setup."
        else
            enable_quotas "$quota_size"
        fi
    else
        echo "  → Skipping quota setup"
    fi
else
    echo "  ✓ User quotas already enabled"
fi

echo ""
echo "[4/6] Installing registration engine..."
cp ssh-autocreate-user.sh /usr/local/bin/ssh-autocreate-user.sh
chmod 755 /usr/local/bin/ssh-autocreate-user.sh

echo "[5/6] Running system infrastructure setup..."
chmod +x setup.sh
./setup.sh

echo "[6/6] Verifying installation..."
# Check if services are running
systemctl is-active --quiet ssh && echo "✓ SSH server running" || echo "✗ SSH server failed"
systemctl is-active --quiet lighttpd && echo "✓ Web server running" || echo "✗ Web server failed"
systemctl is-active --quiet vsftpd && echo "✓ FTP server running" || echo "✗ FTP server failed"

# Check if PAM hook is installed (now in /etc/pam.d/sshd instead of common-auth)
if grep -q "ssh-autocreate-user.sh" /etc/pam.d/sshd; then
    echo "✓ PAM auto-registration hook installed"
else
    echo "✗ PAM hook installation failed"
fi

# Check quota status
if check_quotas; then
    echo "✓ User quotas enabled"
else
    echo "○ User quotas not enabled"
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