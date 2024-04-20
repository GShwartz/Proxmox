## Directory Structure
```
./kvm
  └── bootstrap
      └── kvm-cloudinit
          └── openstack
              └── latest
                  └── user_data
```

## user_data example content:
```
Content-Type: multipart/mixed; boundary="===============0740947994048919689=="
MIME-Version: 1.0

--===============0740947994048919689==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="config"

config system global
        set hostname gil
end

config system admin
        edit admin
        set password Pass1234!
end

config system interface
 edit port1
 set mode static
 set ip 192.168.100.101 255.255.255.0
 set allowaccess ping https http ssh
end

config system dns
 set primary 8.8.8.8
 set secondary 8.8.4.4
end

config router static
    edit 0
    set dst 0.0.0.0 0.0.0.0
    set gateway 192.168.100.2
    set device port1
    next
end

execute shutdown
--===============0740947994048919689==--
```

## iso generation command:
	genisoimage -output /var/lib/vz/template/iso/fgt-config.iso -volid cidata -joliet -rock kvm-cloudinit/