#!/bin/bash

create_vm() {
	local counter=$1
	local ip=$2
	local vname=$3
	local style=$4
	local gate=$5
	local newid=$6
	
	qm create $newid --name $vname --memory $vmram --cores $corenum
	qm importdisk $newid /var/lib/vz/template/iso/ubuntu-22.10-minimal-cloudimg-amd64.img local-lvm
	qm set $newid --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$newid-disk-0
	qm set $newid --ide0 local-lvm:cloudinit
	qm set $newid --boot c --bootdisk scsi0
	qm set $newid --serial0 socket --vga serial0
	qm set $newid --ciuser $sshuser
	qm set $newid --cipassword $sshpass
	qm set $newid --agent 1
	qm set $newid --sshkeys ~/.ssh/gil.pub
	qm set $newid --net0 virtio,bridge=vmbr0
	if [[ $style == "manual" ]]; then
		ip=${ip::-1}
		qm set $newid --ipconfig0 gw="$gate",ip="$ip"$((counter+1))/24
	
	else
		qm set $newid --ipconfig0 ip=dhcp
	
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
read -p "SSH Username: " sshuser

# SSH Password
read -s -p "SSH Password: " sshpass

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
	
	while true; do
		read -p "Gateway IP Address: " gateway
		if validate_ip $gateway; then
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
		newvmid="$(expr $vmid)"
		
	else
		newvmid="$(expr $newvmid + $i)"
				
	fi
	
	create_vm $i $ip $newname $ipaddress $gateway $newvmid &
	
done
wait

# Run first VM for testing
#echo "Staring first VM for testing.."
#qm start $vmid
