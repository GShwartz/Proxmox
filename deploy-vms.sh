#!/bin/bash

create_vm() {
	local counter=$1
	local ip=$2
	local vname=$3
	local style=$4
	
	qm create $vmid --name $vname --memory $vmram --cores $corenum
	qm importdisk $vmid /var/lib/vz/template/iso/ubuntu-22.10-minimal-cloudimg-amd64.img local-lvm
	qm set $vmid --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$vmid-disk-0
	qm set $vmid --ide0 local-lvm:cloudinit
	qm set $vmid --boot c --bootdisk scsi0
	qm set $vmid --serial0 socket --vga serial0
	qm set $vmid --ciuser $sshuser
	qm set $vmid --cipassword $sshpass
	qm set $vmid --agent 1
	qm set $vmid --sshkeys ~/.ssh/gil.pub
	qm set $vmid --net0 virtio,bridge=vmbr0
	if [[ $style == "manual" ]]; then
		ip=${ip::-1}
		qm set $vmid --ipconfig0 gw=192.168.100.2,ip="$ip"$((counter+1))/24
	
	else
		qm set $vmid --ipconfig0 ip=dhcp
	
	fi
	
}

config_images() {
	local minimaldist="ubuntu-22.10-minimal-cloudimg-amd64.img"
	local miniloc="/var/lib/vz/template/iso/ubuntu-22.10-minimal-cloudimg-amd64.img"
	local minilnk="https://cloud-images.ubuntu.com/minimal/releases/kinetic/release/ubuntu-22.10-minimal-cloudimg-amd64.img"
	
	if ! [ -f $miniloc ]; then
		wget $minilnk
		mv ubuntu-22.10-minimal-cloudimg-amd64.img /var/lib/vz/template/iso/
	fi

}

validate_ip () {
	local ip=$1
	local stat=1
	
	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		OIFS=$IFS
		IFS='.'
		ip=($ip)
		IFS=$OIFS
		[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
		stat=$?
	
	fi
	
	return $stat

}

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

# VM OS file
#read -p "VM OS Image: " vmos

# Number of VMS
read -p "Number of VMs: " vmnum

# Starting VM ID
read -p "Starting VM ID: " vmid

# VM Name
read -p "VM Name: " vmname

# RAM for each container
read -p "RAM in MB: " vmram

# Number of Cores
read -p "Cores: " corenum

# Hard Disk Size
read -p "HD Size (GB): " hdsize

# SSH Username
read -p "Username: " sshuser

# SSH Password
read -s -p "Password: " sshpass

while true; do
	echo "IP Address Options"
	echo "------------------"
	echo "1) DHCP"
	echo "2) Manual"
	
	read -p "Enter Choice: " choice
	while [[ ! "$choice" =~ ^[1-2]$ ]]; do
		echo "Invalid input. Please enter a number between 1 and 2."
		read -p "Enter Choice: " choice
	done
	
	case $choice in
		1)
			ipaddress="dhcp"
			break
			;;
			
		2)
			ipaddress="manual"
			break
			;;
					
	esac
done

if [[ $ipaddress == "manual" ]]; then
	while true; do
		read -p "Starting IP Address: " ip
		if validate_ip $ip; then
			break
		
		else
			echo "Input error."
		
		fi
	done
fi

config_images
for ((i=0;i<=$vmnum-1; i++)); do
	newname="${vmname}0$(expr 1 + $i)"
	if [[ $i -eq 0 ]]; then
		newvmid="$(expr $vmid)";
		
	else
		newvmid="$(expr $newvmid + $i)";
		
	fi
	
	create_vm $i $ip $newname $ipaddress
	
done
wait

# Run first VM for testing
echo "Staring first VM for testing.."
qm start $vmid


#qm guest exec $vmid bash "sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"

# Backup one-liner for vm creation
#qm create $newvmid --name $newname --memory $vmram --cores $corenum --ide0 local-lvm:$hdsize --net0 virtio,bridge=vmbr0 --ide1 /var/lib/vz/template/iso/$vmos,media=cdrom --boot c &
