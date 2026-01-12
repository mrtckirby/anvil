#!/bin/bash
# Anvil VM Deployment Script
# Clones a VM, boots it, and automatically installs Anvil

set -e

echo "=========================================="
echo "  Anvil VM Deployment Script"
echo "=========================================="
echo ""

# Configuration
SOURCE_VM=""
NEW_VM_NAME=""
VIRT_PLATFORM=""
VM_USER="ubuntu"
VM_PASSWORD=""
ANVIL_REPO="https://github.com/mrtckirby/anvil.git"
ENABLE_QUOTAS="y"
QUOTA_SIZE_MB="500"

# Detect available virtualization platform
detect_platform() {
    if command -v vboxmanage &> /dev/null; then
        echo "virtualbox"
    elif command -v virsh &> /dev/null; then
        echo "kvm"
    elif command -v vmrun &> /dev/null; then
        echo "vmware"
    else
        echo "none"
    fi
}

# VirtualBox Implementation
clone_virtualbox() {
    echo "[VirtualBox] Cloning VM:  $SOURCE_VM -> $NEW_VM_NAME"
    vboxmanage clonevm "$SOURCE_VM" --name "$NEW_VM_NAME" --register
    
    echo "[VirtualBox] Starting VM..."
    vboxmanage startvm "$NEW_VM_NAME" --type headless
    
    echo "[VirtualBox] Waiting for VM to boot (30s)..."
    sleep 30
    
    # Get VM IP address
    VM_IP=$(vboxmanage guestproperty get "$NEW_VM_NAME" "/VirtualBox/GuestInfo/Net/0/V4/IP" | awk '{print $2}')
    
    if [ -z "$VM_IP" ] || [ "$VM_IP" = "No" ]; then
        echo "Warning: Could not detect VM IP automatically"
        echo "Please enter the VM IP address:"
        read -r VM_IP
    fi
    
    echo "[VirtualBox] VM IP: $VM_IP"
    echo "$VM_IP"
}

# KVM/QEMU Implementation
clone_kvm() {
    echo "[KVM] Cloning VM: $SOURCE_VM -> $NEW_VM_NAME"
    virt-clone --original "$SOURCE_VM" --name "$NEW_VM_NAME" --auto-clone
    
    echo "[KVM] Starting VM..."
    virsh start "$NEW_VM_NAME"
    
    echo "[KVM] Waiting for VM to boot (30s)..."
    sleep 30
    
    # Get VM IP address
    VM_IP=$(virsh domifaddr "$NEW_VM_NAME" | grep -oP '(\d+\. ){3}\d+' | head -1)
    
    if [ -z "$VM_IP" ]; then
        echo "Warning:  Could not detect VM IP automatically"
        echo "Please enter the VM IP address:"
        read -r VM_IP
    fi
    
    echo "[KVM] VM IP: $VM_IP"
    echo "$VM_IP"
}

# VMware Implementation
clone_vmware() {
    echo "[VMware] Cloning VM:  $SOURCE_VM -> $NEW_VM_NAME"
    vmrun clone "$SOURCE_VM" "$NEW_VM_NAME" full
    
    echo "[VMware] Starting VM..."
    vmrun start "$NEW_VM_NAME" nogui
    
    echo "[VMware] Waiting for VM to boot (30s)..."
    sleep 30
    
    # Get VM IP address
    VM_IP=$(vmrun getGuestIPAddress "$NEW_VM_NAME" -wait)
    
    echo "[VMware] VM IP: $VM_IP"
    echo "$VM_IP"
}

# Install Anvil on the VM via SSH
install_anvil() {
    local vm_ip=$1
    
    echo ""
    echo "=========================================="
    echo "  Installing Anvil on VM: $vm_ip"
    echo "=========================================="
    echo ""
    
    # Wait for SSH to be ready
    echo "Waiting for SSH to become available..."
    for i in {1..30}; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 "$VM_USER@$vm_ip" "echo 'SSH Ready'" 2>/dev/null; then
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""
    
    # Clone and install Anvil with automated responses
    echo "Installing Anvil..."
    echo "  Quota settings: Enable=$ENABLE_QUOTAS, Size=${QUOTA_SIZE_MB}MB"
    
    ssh -o StrictHostKeyChecking=no "$VM_USER@$vm_ip" "bash -s" << ENDSSH
        set -e
        cd ~
        if [ -d "anvil" ]; then
            rm -rf anvil
        fi
        git clone $ANVIL_REPO
        cd anvil
        
        # Run install with automated input
        # Provide answers:  quota enable (y/n), then quota size in MB
        printf "${ENABLE_QUOTAS}\n${QUOTA_SIZE_MB}\n" | sudo ./install.sh
ENDSSH
    
    echo ""
    echo "=========================================="
    echo "  Installation Complete!"
    echo "=========================================="
    echo ""
    echo "VM Name: $NEW_VM_NAME"
    echo "VM IP:  $vm_ip"
    echo "Community Directory: http://$vm_ip"
    echo ""
    echo "Users can now SSH to:  ssh username@$vm_ip"
    echo ""
}

# Main script

# Detect platform
VIRT_PLATFORM=$(detect_platform)

if [ "$VIRT_PLATFORM" = "none" ]; then
    echo "ERROR: No supported virtualization platform detected"
    echo "Supported platforms: VirtualBox, KVM/QEMU, VMware"
    exit 1
fi

echo "Detected platform: $VIRT_PLATFORM"
echo ""

# Get source VM name
echo "Enter the name of the source Ubuntu VM to clone:"
read -r SOURCE_VM

# Get new VM name
echo "Enter a name for the new Anvil VM:"
read -r NEW_VM_NAME

# Get VM credentials
echo "Enter the username for the VM (default: ubuntu):"
read -r vm_user_input
if [ -n "$vm_user_input" ]; then
    VM_USER="$vm_user_input"
fi

# Get quota preferences
echo ""
echo "Enable user quotas? (y/n, default: y):"
read -r quota_enable_input
if [ -n "$quota_enable_input" ]; then
    ENABLE_QUOTAS="$quota_enable_input"
fi

if [[ "$ENABLE_QUOTAS" =~ ^[Yy]$ ]]; then
    echo "Quota size per user in MB (default: 500):"
    read -r quota_size_input
    if [ -n "$quota_size_input" ]; then
        QUOTA_SIZE_MB="$quota_size_input"
    fi
fi

echo ""
echo "Summary:"
echo "  Platform: $VIRT_PLATFORM"
echo "  Source VM:  $SOURCE_VM"
echo "  New VM: $NEW_VM_NAME"
echo "  VM User: $VM_USER"
echo "  Quotas:  $ENABLE_QUOTAS (${QUOTA_SIZE_MB}MB)"
echo ""
echo "Proceed with deployment? (y/n)"
read -r confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

# Clone and boot VM based on platform
case "$VIRT_PLATFORM" in
    virtualbox)
        VM_IP=$(clone_virtualbox)
        ;;
    kvm)
        VM_IP=$(clone_kvm)
        ;;
    vmware)
        VM_IP=$(clone_vmware)
        ;;
esac

# Install Anvil
install_anvil "$VM_IP"