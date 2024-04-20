#!/bin/bash

# Check for at least one parameter
if [[ -z "$1" ]]; then
    echo "Usage: $0 <VMID> [VMID2 VMID3 ...] or $0 <VMID-VMID2>"
    exit 1
fi

# Function to process a single VMID
remove_vm() {
    local VMID=$1

    echo "Stopping VM $VMID if it's running..."
    qm stop $VMID --skiplock 1
    sleep 5  # Wait for the VM to properly shutdown

    VM_STATUS=$(qm status $VMID | awk '{print $2}')
    if [[ "$VM_STATUS" == "running" ]]; then
        echo "Failed to stop VM $VMID. Please ensure it is not locked or in use."
        return 1
    fi

    echo "Removing VM $VMID..."
    qm destroy $VMID --purge 1

    echo "VM $VMID has been successfully removed and all associated resources have been freed."
}

# Process each argument
for arg in "$@"; do
    if [[ "$arg" =~ ^[0-9]+-[0-9]+$ ]]; then
        # Argument is a range
        IFS='-' read -ra RANGE <<< "$arg"
        for (( VMID=${RANGE[0]}; VMID<=${RANGE[1]}; VMID++ )); do
            remove_vm $VMID
        done
    elif [[ "$arg" =~ ^[0-9]+$ ]]; then
        # Argument is a single VMID
        remove_vm $arg
    else
        echo "Invalid argument: $arg"
        echo "Usage: $0 <VMID> [VMID2 VMID3 ...] or $0 <VMID-VMID2>"
        exit 1
    fi
done
