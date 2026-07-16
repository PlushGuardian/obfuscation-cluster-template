#!/bin/sh
# Script: cloud_init.sh
# Purpose: Create user 'ansible' with sudo access, add an SSH public key and change ssh port

USERNAME="ansible"
SSH_KEY="${SSH_KEY:-}"                 # e.g. "ssh-ed25519 AAAAC3... user@host"
NEW_SSH_PORT="${NEW_SSH_PORT:-5555}"   # SSH port (optional, defaults to 5555)

if [ -z "$SSH_KEY" ]; then
    echo "Error: SSH_KEY environment variable is not set." >&2
    echo "Please set it in your current terminal before running this script:" >&2
    echo '  export SSH_KEY="ssh-ed25519 AAAAC3... your-public-key-label"' >&2
    exit 1
fi

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: Please run this script as root." >&2
    exit 1
fi

set -e  # Exit immediately if any command fails

#====================================
#            ADD USER
#====================================
echo "=== Creating user $USERNAME ==="
# Create user if not already present
if id "$USERNAME" >/dev/null 2>&1; then
    echo "User '$USERNAME' already exists. Skipping user creation."
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "User '$USERNAME' created with home directory."
fi

# Grant sudo permissions (add to both common groups for compatibility)
if getent group sudo >/dev/null 2>&1; then
    usermod -aG sudo "$USERNAME"
    echo "Added '$USERNAME' to the 'sudo' group."
fi
if getent group wheel >/dev/null 2>&1; then
    usermod -aG wheel "$USERNAME"
    echo "Added '$USERNAME' to the 'wheel' group."
fi
echo "ansible ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/ansible
chmod 440 /etc/sudoers.d/ansible

# Setup SSH directory and authorized_keys
# Get user's home directory using getent (POSIX-compliant)
HOME_DIR=$(getent passwd "$USERNAME" | cut -d: -f6)
if [ -z "$HOME_DIR" ]; then
    # Fallback to standard location if getent fails
    HOME_DIR="/home/$USERNAME"
fi
SSH_DIR="$HOME_DIR/.ssh"
AUTH_KEYS="$SSH_DIR/authorized_keys"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# Append the provided public key
echo "$SSH_KEY" >> "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
chown -R "$USERNAME:$USERNAME" "$SSH_DIR"

echo "SSH key successfully added for user '$USERNAME'."
echo "User setup complete. User '$USERNAME' can now connect using the SSH key and has sudo access."


#====================================
#          CHANGE SSH PORT
#====================================

SSHD_CONFIG="/etc/ssh/sshd_config"
BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%Y%m%d_%H%M%S)"
NEW_SSH_PORT="558" # todo remove

echo "=== Changing SSH port to $NEW_SSH_PORT ==="

# Backup current config
cp "$SSHD_CONFIG" "$BACKUP_FILE"
echo "Backup saved to $BACKUP_FILE"

# Change or add the Port directive
if grep -qE '^#?Port ' "$SSHD_CONFIG"; then
    # Replace existing Port line (commented or not)
    sed -i "s/^#\?Port .*/Port $NEW_SSH_PORT/" "$SSHD_CONFIG"
    echo "Updated Port directive in $SSHD_CONFIG"
else
    # Append Port directive if not present
    echo "Port $NEW_SSH_PORT" >> "$SSHD_CONFIG"
    echo "Added Port directive to $SSHD_CONFIG"
fi

# Reload systemd daemon and restart sshd
echo "Reloading systemd and restarting sshd..."
systemctl daemon-reload
systemctl restart sshd || true  # Ignore errors (connection may drop)

# Wait for the new SSH port to become active
echo "Waiting for SSH to listen on port $NEW_SSH_PORT..."
timeout=30
interval=2
elapsed=0
while [ $elapsed -lt $timeout ]; do
    if ss -tln | grep -q ":$NEW_SSH_PORT "; then
        echo "SSH is now listening on port $NEW_SSH_PORT"
        break
    fi
    sleep $interval
    elapsed=$((elapsed + interval))
done

if [ $elapsed -ge $timeout ]; then
    echo "Error: Timeout waiting for SSH to listen on port $NEW_SSH_PORT"
    echo "Attempting to rollback..."
    cp "$BACKUP_FILE" "$SSHD_CONFIG"
    systemctl restart sshd
    exit 1
fi

systemctl enable ssh
systemctl restart ssh

# Final verification
if systemctl is-active --quiet sshd; then
    echo "✓ sshd is active"
else
    echo "Warning: sshd service is not active" >&2
fi

echo "=== SSH port successfully changed to $NEW_SSH_PORT ==="
echo "Test with: ssh -p $NEW_SSH_PORT $USERNAME@$(hostname -I | awk '{print $1}')"
