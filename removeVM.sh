#!/bin/bash

# Variables
VMID=$1  # VM ID to be passed as the first argument

# Check for required parameter
if [[ -z "$VMID" ]]; then
    echo "Usage: $0 <VMID>"
    exit 1
fi

# Step 1: Ensure the VM is stopped before removal
echo "Stopping VM $VMID if it's running..."
qm stop $VMID --skiplock 1
sleep 5  # Wait for the VM to properly shutdown

# Step 2: Check VM status to confirm it is stopped
VM_STATUS=$(qm status $VMID | awk '{print $2}')
if [[ "$VM_STATUS" == "running" ]]; then
    echo "Failed to stop VM $VMID. Please ensure it is not locked or in use."
    exit 1
fi

# Step 3: Remove the VM
echo "Removing VM $VMID..."
qm destroy $VMID --purge 1

echo "VM $VMID has been successfully removed and all associated resources have been freed."
