#!/bin/bash
# PART 2: THE REGISTRATION ENGINE
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Enable logging for debugging
exec 2>> /var/log/anvil-registration.log
echo "=== $(date) === Script started for user: $PAM_USER" >&2

USER_NAME=$PAM_USER

# 1. Exit immediately if the user exists or is a system account
if getent passwd "$USER_NAME" > /dev/null; then 
    echo "User $USER_NAME already exists, exiting" >&2
    exit 0
fi

case "$USER_NAME" in
    root|ftp|anonymous|www-data|sshd|lighttpd|"") 
        echo "System user $USER_NAME, exiting" >&2
        exit 0 
        ;;
esac

echo "Creating user: $USER_NAME" >&2

# 2. Generate encrypted password (username as password)
ENCRYPTED_PASS=$(openssl passwd -6 "$USER_NAME")
echo "Generated encrypted password" >&2

# 3. Create the User with password in one atomic operation
# Check if --badnames is supported
if useradd --help 2>&1 | grep -q -- '--badnames'; then
    echo "Using --badnames flag" >&2
    useradd -m -s /bin/bash --badnames -p "$ENCRYPTED_PASS" "$USER_NAME" 2>&1 | tee -a /var/log/anvil-registration.log
else
    echo "Using standard useradd (no --badnames)" >&2
    useradd -m -s /bin/bash -p "$ENCRYPTED_PASS" "$USER_NAME" 2>&1 | tee -a /var/log/anvil-registration.log
fi

# Check if user was created successfully
if ! getent passwd "$USER_NAME" > /dev/null; then
    echo "ERROR: Failed to create user $USER_NAME" >&2
    exit 1
fi

echo "User account created successfully" >&2

# 4. Ensure changes are written to disk
sync

# Clear nscd cache if running
if systemctl is-active --quiet nscd 2>/dev/null; then
    nscd -i passwd 2>/dev/null || true
    nscd -i group 2>/dev/null || true
fi

echo "User $USER_NAME created successfully" >&2

# 5. Setup Personal Web Space
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

# 6. Atomic Update of the Community Directory
INDEX_FILE="/var/www/html/index.html"
USER_LINK="<li><a href='/~$USER_NAME/'>$USER_NAME's Site</a></li>"

if [ -f "$INDEX_FILE" ] && ! grep -q "/~$USER_NAME/" "$INDEX_FILE"; then
    TEMP_FILE=$(mktemp)
    sed "/<\/ul>/i $USER_LINK" "$INDEX_FILE" > "$TEMP_FILE"
    mv "$TEMP_FILE" "$INDEX_FILE"
    chmod 664 "$INDEX_FILE"
    chown root:www-data "$INDEX_FILE"
fi

echo "=== $(date) === Script completed for user: $USER_NAME" >&2
exit 0