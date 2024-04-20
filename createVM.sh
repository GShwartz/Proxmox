#!/bin/bash

# Function to display a spinning animation
spin() {
	txt=$1
    spinner="/-\|"
    while :
    do
        for i in `seq 0 3`
        do
            echo -ne "\r${spinner:i:1} $txt"
            sleep 0.1
        done
    done
}

# Variables
VMID=$1  # VM ID to be passed as the first argument
DISK_PATH="/var/lib/vz/template/iso/fortios.qcow2"  # Path to the QCOW2 disk image
CLOUD_INIT_ISO="fgt-config.iso"  # Filename of the Cloud-Init ISO
TOTAL_TIME=70	# Time to wait for the cloud-init initial configuration

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

echo "Waiting for installation to complete..."
for i in $(seq 1 $TOTAL_TIME); do
    # Start the spinner in the background
    spin "VM $VMID status: $VM_STATUS..." &
    SPINNER_PID=$!

    # Check the VM status
    VM_STATUS=$(qm status $VMID | awk '{print $2}')

    # Stop the spinner
    kill $SPINNER_PID > /dev/null 2>&1
    wait $SPINNER_PID 2>/dev/null
    echo -ne ""

    # Break the loop if VM is stopped
    if [[ "$VM_STATUS" == "stopped" ]]; then
        break
    fi
done

echo -e "\nVM $VMID status: stopped."
echo "VM $VMID created successfully."