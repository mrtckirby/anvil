#!/bin/bash
#
# SSH PAM User Auto-Creation and Authentication Script
#
# This script serves dual purposes in the PAM authentication chain:
# 1. Creates new users automatically when they don't exist
# 2. Authenticates newly created users immediately (returns success)
#
# Return codes:
# - Exit 0: User was newly created - authentication succeeds
# - Exit 1: User already exists - fall through to pam_unix for password authentication
#
# Usage: Called by PAM with username as first argument

# Get the username from PAM
PAM_USER="$1"

# Validate username is provided
if [ -z "$PAM_USER" ]; then
    exit 1
fi

# Check if user already exists
if id "$PAM_USER" &>/dev/null; then
    # User exists, return 1 to fall through to pam_unix for authentication
    exit 1
fi

# User doesn't exist - create it
useradd -m -s /bin/bash "$PAM_USER"

# Check if user creation was successful
if [ $? -eq 0 ]; then
    # User created successfully
    # Return 0 to indicate authentication success for the newly created user
    exit 0
else
    # User creation failed, return 1
    exit 1
fi
