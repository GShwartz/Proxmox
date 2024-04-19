#!/bin/bash

# Variables
VMID=$1
DISK_PATH="/var/lib/vz/template/iso/fortios.qcow2"
CLOUD_INIT_ISO="fgt-bootstrap.iso"

# Check for required parameter
if [[ -z "$VMID" ]]; then
    echo "Usage: $0 <VMID>"
    exit 1
fi

# Step 1: Create the VM
echo "Creating VM with ID $VMID..."
qm create $VMID --name "FortiGateVM-$VMID" --memory 2048 --cores 1 --net0 virtio,bridge=vmbr0 --ostype l26

# Step 2: Import the disk to local-lvm storage
echo "Importing disk from QCOW2 image..."
qm importdisk $VMID $DISK_PATH local-lvm --format raw

# Step 3: Attach the disk to the VM
echo "Attaching imported disk to VM..."
qm set $VMID --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$VMID-disk-0

# Step 4: Attach the CloudInit drive
echo "Attaching CloudInit ISO..."
qm set $VMID --ide2 local:iso/$CLOUD_INIT_ISO,media=cdrom

# Step 5: Set the boot order to CloudInit drive
echo "Setting boot order..."
qm set $VMID --boot c --bootdisk scsi0

# Step 6: Set the VGA display
echo "Configuring VGA display..."
qm set $VMID --vga std

# Step 7: Add a NIC
echo "Adding a network interface card (NIC)..."
qm set $VMID --net0 virtio,bridge=vmbr0

# Step 8: Start the VM
#echo "Starting the VM..."
#qm start $VMID

echo "VM $VMID has been created and started successfully!"


