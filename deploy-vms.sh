#!/bin/bash

# VM OS
echo "Storage Status:"
pvesm status
echo "================"
echo "----========----"
echo "ISO Images"
ls -l /var/lib/vz/template/iso
echo ""
read -p "VM OS Image: " vmos

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

for ((i=0;i<=$vmnum-1; i++)); do
	newname="${vmname}0$(expr 1 + $i)"
	newvmid="$(expr $vmid + $i)"
	echo "Creating VM $newname..."
	qm create $newvmid --name $newname --memory $vmram --cores $corenum --ide0 local-lvm:$hdsize --net0 virtio,bridge=vmbr0 --ide1 /var/lib/vz/template/iso/$vmos,media=cdrom --boot c &
done
