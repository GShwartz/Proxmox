#!/bin/bash

echo "========================================================================================"
echo "					Storage Status:	                                                      "
echo "========================================================================================"
pvesm status
echo ""

echo "----========--------========--------========--------========--------========--------"
echo "					ISO Images                                                        " 
echo "----========--------========--------========--------========--------========--------"
ls -l /var/lib/vz/template/iso
echo ""

# VM OS
#read -p "VM OS Image: " vmos

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

create_vm() {
	local lvmname="$1"
	local lvmid="$2"
	
	qm create $lvmid --name $lvmname --memory $vmram --cores $corenum --ide0 local-lvm:$hdsize --net0 virtio,bridge=vmbr0 --ide1 /var/lib/vz/template/iso/ubuntu-22.04.1-live-server-amd64.iso,media=cdrom --boot c &
 
}

for ((i=0;i<=$vmnum-1; i++)); do
	newname="${vmname}0$(expr 1 + $i)"
	if [[ $i -eq 0 ]]; then
		newvmid="$(expr $vmid)";
		
	else
		newvmid="$(expr $newvmid + $i)";
		
	fi
	
	echo "Creating VM $newname..."
	create_vm $newname $newvmid
	#qm create $newvmid --name $newname --memory $vmram --cores $corenum --ide0 local-lvm:$hdsize --net0 virtio,bridge=vmbr0 --ide1 /var/lib/vz/template/iso/$vmos,media=cdrom --boot c &
done
