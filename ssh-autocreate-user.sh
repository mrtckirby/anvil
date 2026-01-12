#!/bin/bash
# PART 2: THE REGISTRATION ENGINE
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

USER_NAME=$PAM_USER

# 1. Exit immediately if the user exists or is a system account
if getent passwd "$USER_NAME" > /dev/null; then exit 0; fi
case "$USER_NAME" in
    root|ftp|anonymous|www-data|sshd|lighttpd|"") exit 0 ;;
esac

# 2. Generate encrypted password (username as password)
ENCRYPTED_PASS=$(openssl passwd -6 "$USER_NAME")

# 3. Create the User with password in one atomic operation
# --badnames allows capitals/dots; -p sets encrypted password
useradd -m -s /bin/bash --badnames -p "$ENCRYPTED_PASS" "$USER_NAME"

# 4. Force password change on first successful login
passwd -e "$USER_NAME" 2>/dev/null

# 5. Ensure changes are written to disk
sync

# Clear nscd cache if running
if systemctl is-active --quiet nscd 2>/dev/null; then
    nscd -i passwd 2>/dev/null || true
    nscd -i group 2>/dev/null || true
fi

# 6. Setup Personal Web Space
USER_HOME="/home/$USER_NAME"
mkdir -p "$USER_HOME/public_html"
cat << WEBEOF > "$USER_HOME/public_html/index.html"
<!DOCTYPE html>
<html>
<head><style>body{text-align:center;font-family:sans-serif;padding-top:50px;}</style></head>
<body><h1>Welcome to ${USER_NAME}'s web page!</h1></body>
</html>
WEBEOF

chown -R "$USER_NAME:$USER_NAME" "$USER_HOME"
chmod 755 "$USER_HOME"
chmod 755 "$USER_HOME/public_html"

# 7. Atomic Update of the Community Directory
INDEX_FILE="/var/www/html/index.html"
USER_LINK="<li><a href='/~$USER_NAME/'>$USER_NAME's Site</a></li>"

if [ -f "$INDEX_FILE" ] && ! grep -q "/~$USER_NAME/" "$INDEX_FILE"; then
    TEMP_FILE=$(mktemp)
    sed "/<\/ul>/i $USER_LINK" "$INDEX_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$INDEX_FILE"
    chmod 664 "$INDEX_FILE"
    chown root:www-data "$INDEX_FILE"
fi

exit 0