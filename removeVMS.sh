#!/bin/bash

# Configuration
MAX_JOBS=10  # Maximum number of concurrent jobs
SLEEP_DURATION=5  # Adjustable sleep time for flexibility
TIMEOUT_DURATION=10  # Timeout for stopping the VM before trying to pause it
RETRY_LIMIT=3  # Maximum number of pause attempts

# Check for at least one parameter
if [[ -z "$1" ]]; then
    echo "Usage: $0 <VMID> [VMID2 VMID3 ...] or $0 <VMID-VMID2>"
    exit 1
fi

# Function to process a single VMID
remove_vm() {
    local VMID=$1
    local VM_STATUS=$(qm status $VMID | awk '{print $2}')
    local attempt_count=0

    echo "Attempting to stop VM $VMID..."
    qm stop $VMID --skiplock 1
    sleep $SLEEP_DURATION  # Wait for the VM to potentially shutdown

    # Re-check the VM status to determine next steps
    VM_STATUS=$(qm status $VMID | awk '{print $2}')
    while [[ "$VM_STATUS" == "running" || "$VM_STATUS" == "paused" ]]; do
        if [[ "$VM_STATUS" == "paused" ]]; then
            echo "VM $VMID is paused. Attempting to resume and stop..."
            qm resume $VMID
            sleep $SLEEP_DURATION
        fi

        echo "VM $VMID did not stop, attempting to pause..."
        qm suspend $VMID --skiplock 1
        sleep $TIMEOUT_DURATION

        # Check status again after attempting to pause
        VM_STATUS=$(qm status $VMID | awk '{print $2}')
        if [[ "$VM_STATUS" == "paused" ]]; then
            echo "Attempting forceful stop of VM $VMID..."
            qm stop $VMID --skiplock 1 # --forceStop 1
            sleep $SLEEP_DURATION
        fi

        # Update VM status for the loop condition
        VM_STATUS=$(qm status $VMID | awk '{print $2}')
        ((attempt_count++))
        if [[ $attempt_count -ge $RETRY_LIMIT ]]; then
            echo "Failed to stop VM $VMID after $RETRY_LIMIT attempts."
            return 1
        fi
    done

    echo "Removing VM $VMID..."
    qm destroy $VMID --purge 1
    echo "VM $VMID has been successfully removed and all associated resources have been freed."
}

# Function to manage background processes and limit job count
process_vms() {
    local job_count=0
    for arg in "$@"; do
        if [[ "$arg" =~ ^[0-9]+-[0-9]+$ ]]; then
            IFS='-' read -ra RANGE <<< "$arg"
            for (( VMID=${RANGE[0]}; VMID<=${RANGE[1]}; VMID++ )); do
                ((job_count++))
                remove_vm $VMID &
                if [[ $job_count -ge $MAX_JOBS ]]; then
                    wait -n  # Wait for any background job to finish
                    ((job_count--))
                fi
            done
        elif [[ "$arg" =~ ^[0-9]+$ ]]; then
            ((job_count++))
            remove_vm $arg &
            if [[ $job_count -ge $MAX_JOBS ]]; then
                wait -n  # Wait for any background job to finish
                ((job_count--))
            fi
        else
            echo "Invalid argument: $arg"
            echo "Usage: $0 <VMID> [VMID2 VMID3 ...] or $0 <VMID-VMID2>"
            exit 1
        fi
    done
    wait  # Wait for all remaining background jobs to finish
}

# Process all arguments
process_vms "$@"
