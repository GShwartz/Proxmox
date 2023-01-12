#!/bin/bash

# TODO: 
# 	1. Create more distro options for cloud-init
#	2. Create & Enable SSH connections

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

# SSH Username
read -p "SSH Username: " sshuser

# SSH Password
read -s -p "SSH Password: " sshpass
echo ""

create_vm() {
	local lvmname="$1"
	local lvmid="$2"
	local counter=$3
	
	#qm create $lvmid --name $lvmname --memory $vmram --cores $corenum --ide0 local-lvm:$hdsize --net0 virtio,bridge=vmbr0 --ide1 /var/lib/vz/template/iso/ubuntu-22.04.1-live-server-amd64.iso,media=cdrom --boot c &
	qm create $lvmid --name $lvmname --memory $vmram --cores $corenum
	qm importdisk $lvmid /var/lib/vz/template/iso/bionic-server-cloudimg-amd64.img local-lvm
	qm set $lvmid --net0 virtio,bridge=vmbr0
	qm set $lvmid --ipconfig0 gw=192.168.100.2,ip=192.168.100.10$((counter+1))/24
	qm set $lvmid --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$lvmid-disk-0
	qm set $lvmid --ide0 local-lvm:cloudinit
	qm set $lvmid --boot c --bootdisk scsi0
	qm set $lvmid --serial0 socket --vga serial0
	qm set $lvmid --ciuser $sshuser
	qm set $lvmid --cipassword $sshpass
	
}

distro="bionic-server-cloudimg-amd64.img"
distloc="/var/lib/vz/template/iso/bionic-server-cloudimg-amd64.img"
distlnk="https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
if ! [ -f $distloc ]; then
	wget $distlnk
	mv bionic-server-cloudimg-amd64.img /var/lib/vz/template/iso/
fi

for ((i=0;i<=$vmnum-1; i++)); do
	newname="${vmname}0$(expr 1 + $i)"
	if [[ $i -eq 0 ]]; then
		newvmid="$(expr $vmid)";
		
	else
		newvmid="$(expr $newvmid + $i)";
		
	fi
	
	echo "Creating VM $newname..."
	create_vm $newname $newvmid $i &
	
done
wait

echo "Staring first VM for testing.."
qm start $vmid

# Backup one-liner for vm creation
#qm create $newvmid --name $newname --memory $vmram --cores $corenum --ide0 local-lvm:$hdsize --net0 virtio,bridge=vmbr0 --ide1 /var/lib/vz/template/iso/$vmos,media=cdrom --boot c &
