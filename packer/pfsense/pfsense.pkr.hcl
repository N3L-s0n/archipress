source "virtualbox-iso" "local"{

    iso_url = var.iso_url
    iso_checksum = var.iso_checksum

    cpus = 1
    memory = 1024
    disk_size = 8192 # 8 GB disk size
    
    boot_wait = "1m30s"
    boot_command = [
        # Accept Copyright
        "<enter><wait2s>",
        # Options: Install ...
        "<enter><wait2s>",
        # Continue with default keymap
        "<enter><wait2s>",
        # Options: Auto (ZFS), Auto (UFS) Bios ...
        "<down><enter><wait5m>",
        # Manual Configuration Default No
        "<enter><wait20s><enter><wait5m>",

        # After reboot
        # n to avoid setting vlans
        # vmx0 for wan interface name
        # vmx1 for lan interface name
        "n<enter><wait>vmx0<enter><wait>vmx1<enter><wait>y<enter><wait20s>",
        # Set wan interface
        "2<enter><wait>1<enter><wait>n<enter><wait>172.24.133.64<enter><wait>24<enter><wait>",
        # Gateway address
        "172.24.133.1<enter><wait>n<enter><wait><enter><wait>y<enter><wait15s><enter><wait10s>",
        # Enable sshd
        "14<enter><wait>y<enter><wait>"

    ]

    shutdown_command = "8<enter>reboot<enter>"

    headless = false
    guest_os_type = "other"

    communicator = "none"
}



source "vmware-iso" "esxi"{

    vm_name = "pfsense"
    vmdk_name = "pfsenseDisk"

    iso_url = var.iso_url
    iso_checksum = var.iso_checksum

    cpus = 1
    memory = 1024
    disk_size = 8192 # 8 GB disk size
    disk_type_id = "thin" # Thin provisioning

    boot_wait = "1m20s"
    boot_command = [
        # Accept Copyright
        "<enter><wait2s>",
        # Options: Install ...
        "<enter><wait2s>",
        # Continue with default keymap
        "<enter><wait2s>",
        # Options: Auto (ZFS), Auto (UFS) Bios ...
        "<down><enter><wait5m>",
        #"<enter><wait5s><enter><wait5s><enter><wait5><space><wait><enter><wait5s><left><enter><wait5m>"
        # Manual Configuration Default No
        "<enter><wait10s><enter><wait5m>",

        # Set wan interface
        "2<enter><wait>1<enter><wait>n<enter><wait>${var.ssh_host}<enter><wait>24<enter><wait>",
        # Gateway address
        "${var.gateway}<enter><wait>n<enter><wait><enter><wait>y<enter><wait15s><enter><wait10s>",
        # Enable sshd
        "14<enter><wait>y<enter><wait>",

        # Allow wan rules
        "8<enter><wait>pfSsh.php playback enableallowallwan<enter><wait20s>",

        # Install Open-VM-Tools
        "pkg install -y pfSense-pkg-Open-VM-Tools<enter><wait40s>",

        # Wait 3 minutes to change password
        "<wait3m>"
    ]

    shutdown_command = "shutdown -p now"

    headless = false
    guest_os_type = "freeBSD"

    communicator = "ssh"

    ssh_port = 22
    ssh_host = var.ssh_host
    ssh_username = var.ssh_username
    ssh_password = var.ssh_password
    ssh_wait_timeout = "10m"

    remote_type             = "esx5"
    remote_host             = var.esxi_host
    remote_datastore        = var.esxi_datastore
    remote_cache_datastore  = var.esxi_cache_datastore
    remote_cache_directory  = "packer"
    remote_username         = var.esxi_username
    remote_password         = var.esxi_password

    # This must be set to "true" when using VNC with ESXi 6.5 or 6.7.
    vnc_disable_password    = true

    network_name = "WAN"

    vmx_data = {
        "ethernet0.present" = "TRUE"
        "ethernet0.networkName" = "WAN"
        "ethernet0.virtualDev" = "e1000e"
        "ethernet0.startConnected" = "TRUE"

        "ethernet1.present" = "TRUE"
        "ethernet1.networkName" = "LAN"
        "ethernet1.virtualDev" = "e1000e"
        "ethernet1.startConnected" = "TRUE"

        #"ethernet2.present" = "TRUE"
        #"ethernet2.networkName" = "NAC"
        #"ethernet2.virtualDev" = "e1000e"
        #"ethernet2.startConnected" = "TRUE"
    }

    format = "vmx"
    keep_registered = true
    vmx_remove_ethernet_interfaces = true
}


build {

    sources = ["source.vmware-iso.esxi", "source.virtualbox-iso.local"]

    provisioner "shell" {
        inline = [
            "echo 'testing ssh'"
        ]
    }

    provisioner "ansible" {
        playbook_file = "packer/pfsense/setup.yml"
        use_proxy = false
        extra_arguments = [
            "--extra-vars", "ansible_user=${var.ssh_username} ansible_password=${var.ssh_password}"
        ]
    }

    post-processor "vagrant" {
        keep_input_artifact = true
        output = "vagrant/boxes/pfsense_{{.BuildName}}.box"
    }
}
