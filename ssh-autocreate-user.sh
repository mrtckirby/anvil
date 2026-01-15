#!/bin/bash

# Function to handle SSH user creation

# Exit codes: 0 = success (auth OK), 1 = failure (defer to next PAM module)

# Note: OpenSSH checks user existence before PAM runs, so new users require two login attempts.

USER_NAME=$1

if id "$USER_NAME" &>/dev/null; then
    echo "User $USER_NAME already exists, proceeding with normal authentication."
    exit 0
fi

# Community directory section...

echo "=== $(date) === Account created for $USER_NAME. Please reconnect to login. ===" >&2
exit 0