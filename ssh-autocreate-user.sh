#!/bin/bash

# PART 2: THE REGISTRATION ENGINE
# Creates user accounts on first SSH login attempt. User must login twice.

# This script is called by PAM during SSH authentication.
# It receives the username as the first argument.
# PAM passes: username via $1, and password via stdin (if pam_exec configured to expose it)

# For Anvil, we use a simple approach: username = initial password

# Exit codes: Script runs in 'optional' mode, exit code doesn't affect auth

USER_NAME=$1

if id "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME already exists, deferring to pam_unix" >&2
    exit 0  # Exit cleanly for existing users
fi

# Validate username (alphanumeric, underscore, hyphen only)
if ! [[ "$USER_NAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "Invalid username format: $USER_NAME" >&2
    exit 1
fi

# Create user with home directory
# Initial password = username (user will be forced to change it)
echo "Creating user account: $USER_NAME" >&2

# Create the user
if ! useradd -m -s /bin/bash "$USER_NAME"; then
    echo "Failed to create user $USER_NAME" >&2
    exit 1
fi

# Set initial password (username = password)
if ! echo "$USER_NAME:$USER_NAME" | chpasswd; then
    echo "Failed to set password for $USER_NAME" >&2
    # Don't fail, user is created
fi

# Force password change on first login
chage -d 0 "$USER_NAME"

# Apply quota if configured
if [ -f /etc/anvil-quota-mb ]; then
    QUOTA_MB=$(cat /etc/anvil-quota-mb)
    if [ "$QUOTA_MB" -gt 0 ]; then
        setquota -u "$USER_NAME" $((QUOTA_MB * 1024)) $((QUOTA_MB * 1024 + 10240)) 0 0 / 2>/dev/null || true
    fi
fi

# Get user's home directory
USER_HOME=$(getent passwd "$USER_NAME" | cut -d: -f6)

echo "User $USER_NAME created successfully - please reconnect to login" >&2

# Create public_html directory for user's website
mkdir -p "$USER_HOME/public_html"
chown "$USER_NAME:$USER_NAME" "$USER_HOME/public_html"
chmod 755 "$USER_HOME/public_html"

# Create a default welcome page
cat << WEBEOF > "$USER_HOME/public_html/index.html"
<!DOCTYPE html>
<html>
<head>
    <title>$USER_NAME's Page</title>
    <style>
        body { font-family: sans-serif; background: #34495e; color: white; text-align: center; padding: 50px; }
        h1 { font-size: 3em; }
        p { font-size: 1.2em; }
    </style>
</head>
<body>
    <h1>Welcome to $USER_NAME's page!</h1>
    <p>This is your personal web space on the Anvil server.</p>
    <p>Edit this file at: <code>~/public_html/index.html</code></p>
</body>
</html>
WEBEOF

chown "$USER_NAME:$USER_NAME" "$USER_HOME/public_html/index.html"
chmod 644 "$USER_HOME/public_html/index.html"

echo "Account created! User must attempt login again to authenticate." >&2

echo "=== $(date) === User $USER_NAME account created. Ready for next login. ===" >&2

# Exit cleanly - user account is ready for authentication on next login
exit 0
