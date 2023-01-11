#!/bin/bash

# Number of VMS
read -p "Number of VMs: " vmnum

# Starting VM ID
read -p "Starting VM ID: " vmid

# VM Name
read -p "VM Name (will show VMname + VMid): " vmname

# RAM for each container
read -p "RAM for each VM in MB: " vmram

# Number of Cores
read -p "Cores: " corenum

# Hard Disk Size
read -p "HD Size: " hdsize

for ((i=1;i<=$vmnum; i++)); do
	newname="${vmname}0$(expr 0 + $i)"
	vmid="$(expr 100 + $i)"
	echo "Creating VM $newname..."
	qm create $vmid --name $newname --memory $vmram --cores $corenum --ide0 local-lvm:$hdsize --net0 virtio,bridge=vmbr0 --ide1 /var/lib/vz/template/iso/ubuntu-22.04.1-live-server-amd64.iso,media=cdrom --boot c &
done
