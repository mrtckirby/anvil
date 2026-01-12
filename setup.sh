#!/bin/bash
# PART 1: SYSTEM INFRASTRUCTURE

# 1. Clean up all previous PAM attempts to avoid conflicts
sed -i '/ssh-autocreate-user.sh/d' /etc/pam.d/sshd
sed -i '/ssh-autocreate-user.sh/d' /etc/pam.d/common-auth
sed -i '/ssh-autocreate-user.sh/d' /etc/pam.d/common-account
sed -i '/pam_permit.so/d' /etc/pam.d/sshd

# 2. Configure SSH correctly (Using only modern, stable settings)
sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^#\?UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

# 3. Backup and modify PAM sshd configuration
cp /etc/pam.d/sshd /etc/pam.d/sshd.backup

# Create a new sshd PAM config with our hook at the top
cat > /etc/pam.d/sshd << 'PAMEOF'
# Anvil auto-registration hook - MUST run first
auth       sufficient   pam_exec.so /usr/local/bin/ssh-autocreate-user.sh

# Standard Un*x authentication
@include common-auth

# Disallow non-root logins when /etc/nologin exists
account    required     pam_nologin.so

# Disallow non-root logins when /etc/nologin exists
account    required     pam_limits.so

# Standard Un*x account phase
@include common-account

# SELinux needs to be the first session rule
session [success=ok ignore=ignore module_unknown=ignore default=bad] pam_selinux.so close

# Set up user limits from /etc/security/limits.conf
session    required     pam_limits.so

# Standard Un*x session setup and teardown
@include common-session

# Print the message of the day upon successful login
session    optional     pam_motd.so  motd=/run/motd.dynamic
session    optional     pam_motd.so noupdate

# Print the status of the user's mailbox upon successful login
session    optional     pam_mail.so standard noenv

# Create a new session keyring
session    optional     pam_loginuid.so

# SELinux needs to intervene at login time to ensure that the process starts
session [success=ok ignore=ignore module_unknown=ignore default=bad] pam_selinux.so open

# Standard Un*x password updating
@include common-password
PAMEOF

systemctl restart ssh

echo "PAM configuration updated. Verifying..."
grep -n "ssh-autocreate-user.sh" /etc/pam.d/sshd || echo "WARNING: Hook not found in PAM config!"

# 4. Initialize the Community Directory Page
mkdir -p /var/www/html
cat << 'EOF' > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head><title>Anvil Community</title><style>body{font-family:sans-serif;background:#2c3e50;color:white;text-align:center;}li{margin:10px;font-size:1.2em;}a{color:#3498db;text-decoration:none;}</style></head>
<body><h1>Anvil Community Directory</h1><hr><ul></ul></body></html>
EOF
chown root:www-data /var/www/html/index.html
chmod 664 /var/www/html/index.html

# 5. Configure vsftpd for Anonymous & Local Access
cat << 'EOF' > /etc/vsftpd.conf
listen=YES
listen_ipv6=NO
connect_from_port_20=YES
write_enable=YES
local_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
local_umask=022
anonymous_enable=YES
no_anon_password=YES
anon_root=/srv/ftp
pam_service_name=vsftpd
secure_chroot_dir=/var/run/vsftpd/empty
EOF
mkdir -p /srv/ftp/public && chmod 755 /srv/ftp/public
systemctl restart vsftpd lighttpd
