#!/bin/bash

# Variables
VMID=$1  # VM ID to be passed as the first argument
DISK_PATH="/var/lib/vz/template/iso/fortios.qcow2"  # Path to the QCOW2 disk image
CLOUD_INIT_ISO="fgt-config.iso"  # Filename of the Cloud-Init ISO
SLEEP_DURATION=5	# Time to wait for the VM to stop
TIMEOUT_DURATION=10	# Time to wait for the VM to pause
RETRY_LIMIT=3	# Number of times to try to stop the VM until return 1
TOTAL_TIME=70	# Time to wait for the cloud-init initial configuration


stop_vm() {
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

    echo "VM $VMID has been successfully stopped."
}

# Check for required parameter
if [[ -z "$VMID" ]]; then
    echo "Usage: $0 <VMID>"
    exit 1
fi

# Create VM
echo "Creating VM with ID $VMID..."
qm create $VMID --name "FortiGateVM-$VMID" --memory 2048 --cores 1 \
                --net0 virtio,bridge=vmbr0 --ostype l26 \
                --scsihw virtio-scsi-pci --vga std \
				--arch x86_64

# Step 2: Import the disk to local-lvm storage
echo "Importing disk from QCOW2 image..."
qm importdisk $VMID $DISK_PATH local-lvm --format raw

# Step 3: Attach the disk to the VM
echo "Attaching imported disk to VM..."
qm set $VMID --scsi0 local-lvm:vm-$VMID-disk-0

# Step 4: Setup and Attach the CloudInit drive
echo "Setting up and attaching CloudInit drive..."
qm set $VMID --ide2 local:iso/$CLOUD_INIT_ISO,media=cdrom  # added format=raw,cache=none

# Step 5: Configure VM to boot from the CloudInit drive first, then from SCSI drive
echo "Configuring VM to boot from the CloudInit drive first..."
qm set $VMID --boot order="ide2;scsi0"

# Step 6: Enable QEMU agent
echo "Enabling QEMU agent..."
qm set $VMID --agent 1

# Step 7: Start the VM
echo "Starting VMID $VMID for initial install..."
qm start $VMID

echo "Starting installation wait..."
bar_length=40  # Fixed size of the progress bar
echo -n "Progress: ["
for i in $(seq 1 $TOTAL_TIME); do
    sleep 1
    # Calculate the percentage of completion
    percent=$((i * 100 / $TOTAL_TIME))
    filled_length=$((i * bar_length / $TOTAL_TIME)) # Calculate how much of the bar to fill

    # Create the bar strings: filled part and empty part
    printf -v filled '%*s' "$filled_length" ''
    printf -v empty '%*s' "$((bar_length - filled_length))" ''

    # Print the bar: filled with #, and the rest is empty
    printf "\rProgress: [%-${bar_length}s] %3d%%" "${filled// /+}${empty}" "$percent"
done
echo -e "\nInstallation wait period complete."

echo "VM $VMID created successfully."