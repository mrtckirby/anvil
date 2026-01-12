#!/bin/bash
# PART 1: SYSTEM INFRASTRUCTURE

# 1. Clean up all previous PAM attempts to avoid conflicts
sed -i '/ssh-autocreate-user.sh/d' /etc/pam.d/sshd
sed -i '/ssh-autocreate-user.sh/d' /etc/pam.d/common-auth
sed -i '/ssh-autocreate-user.sh/d' /etc/pam.d/common-account

# 2. Configure SSH correctly (Using only modern, stable settings)
sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
sed -i 's/^#\?UseDNS.*/UseDNS no/' /etc/ssh/sshd_config

# 3. Add the hook DIRECTLY to sshd's PAM config, BEFORE common-auth is included
# This ensures the user is created before any authentication checks
if ! grep -q "ssh-autocreate-user.sh" /etc/pam.d/sshd; then
    # Insert before the first auth line (usually @include common-auth)
    sed -i '/^@include common-auth/i auth    requisite    pam_exec.so quiet /usr/local/bin/ssh-autocreate-user.sh' /etc/pam.d/sshd
    sed -i '/^@include common-auth/i account  requisite    pam_permit.so' /etc/pam.d/sshd
fi

systemctl restart ssh

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
