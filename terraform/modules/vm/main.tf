terraform {
  required_providers {
    vsphere = {
      source  = "vmware/vsphere"
      version = "~> 2.15"
    }
    null = {
      source = "hashicorp/null"
    }
  }
}

data "vsphere_datacenter" "dc" { name = var.datacenter }

data "vsphere_datastore" "ds" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "clu" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "net" {
  name          = var.network
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

resource "vsphere_virtual_machine" "vm" {
  name             = var.vm_name
  folder           = var.vm_folder
  resource_pool_id = data.vsphere_compute_cluster.clu.resource_pool_id
  datastore_id     = data.vsphere_datastore.ds.id

  num_cpus  = var.cpu_count
  memory    = var.memory_mb
  guest_id  = data.vsphere_virtual_machine.template.guest_id
  firmware  = data.vsphere_virtual_machine.template.firmware
  scsi_type = data.vsphere_virtual_machine.template.scsi_type

  network_interface {
    network_id   = data.vsphere_network.net.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  dynamic "clone" {
    for_each = [1]
    content {
      template_uuid = data.vsphere_virtual_machine.template.id
    }
  }

  disk {
    label            = "osdisk"
    size             = var.disk_size_gb
    thin_provisioned = var.thin_provisioned
  }

  dynamic "disk" {
    for_each = var.data_disk_size_gb > 0 ? [1] : []
    content {
      label            = "datadisk"
      size             = var.data_disk_size_gb
      thin_provisioned = var.thin_provisioned
      unit_number      = 1
    }
  }

  wait_for_guest_net_timeout = 600
  wait_for_guest_ip_timeout  = 600
}

resource "null_resource" "mount_data_disk" {
  count = var.data_disk_size_gb > 0 ? 1 : 0

  triggers = { vm_id = vsphere_virtual_machine.vm.id }

  connection {
    type        = "ssh"
    host        = vsphere_virtual_machine.vm.default_ip_address
    user        = var.vm_ssh_user
    private_key = var.ssh_private_key
    timeout     = "10m"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      "for i in {1..60}; do [ -b /dev/sdb ] && break || sleep 2; done",
      "if [ \"${var.data_fs_type}\" = xfs ]; then command -v mkfs.xfs >/dev/null 2>&1 || timeout 180 dnf -y install xfsprogs || true; fi",
      "if [ \"${var.data_fs_type}\" = ext4 ]; then command -v mkfs.ext4 >/dev/null 2>&1 || timeout 180 dnf -y install e2fsprogs || true; fi",
      "command -v wipefs >/dev/null 2>&1 || timeout 180 dnf -y install util-linux || true",
      "if findmnt -rn -S /dev/sdb || findmnt -rn -T ${var.data_mount_point}; then echo 'Already mounted'; exit 0; fi",
      "FSTYPE=$(lsblk -no FSTYPE /dev/sdb | head -n1 || true)",
      "if [ -z \"$FSTYPE\" ] || [ \"$FSTYPE\" != \"${var.data_fs_type}\" ]; then \\",
      "  umount -lf /dev/sdb 2>/dev/null || true; \\",
      "  for p in /dev/sdb?*; do [ -b \"$p\" ] && umount -lf \"$p\" || true; done; \\",
      "  sfdisk --delete /dev/sdb || true; \\",
      "  partx -d /dev/sdb || true; \\",
      "  wipefs -fa /dev/sdb || true; \\",
      "  udevadm settle || true; sleep 2; \\",
      "  if [ \"${var.data_fs_type}\" = xfs ]; then \\",
      "    for i in 1 2 3 4 5; do mkfs.xfs -f /dev/sdb && break || sleep 2; done; \\",
      "  elif [ \"${var.data_fs_type}\" = ext4 ]; then \\",
      "    mkfs.ext4 -F /dev/sdb; \\",
      "  else \\",
      "    mkfs -t ${var.data_fs_type} /dev/sdb; \\",
      "  fi; \\",
      "fi",
      "mkdir -p ${var.data_mount_point}",
      "udevadm settle || true; sleep 1",
      "UUID=$(blkid -s UUID -o value /dev/sdb 2>/dev/null || true)",
      "if [ -z \"$UUID\" ]; then UUID=$(lsblk -no UUID /dev/sdb | head -n1 || true); fi",
      "LINE=\"UUID=$UUID ${var.data_mount_point} ${var.data_fs_type} defaults,nofail 0 2\"",
      "awk '$2 != \"${var.data_mount_point}\" {print}' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab",
      "grep -qxF \"$LINE\" /etc/fstab || echo \"$LINE\" >> /etc/fstab",
      "systemctl daemon-reload || true",
      "mount -a",
      "findmnt -rn -T ${var.data_mount_point}"
    ]
  }
}

# Optionally configure a static IPv4 address inside the guest using NetworkManager (nmcli)
resource "null_resource" "configure_static_ip" {
  count = length(var.ipv4_address) > 0 ? 1 : 0

  triggers = {
    vm_id        = vsphere_virtual_machine.vm.id
    ipv4_address = var.ipv4_address
    ipv4_netmask = var.ipv4_netmask
    ipv4_gateway = var.ipv4_gateway
    dns_servers  = join(",", var.dns_server_list)
    domain       = var.domain
  }

  connection {
    type        = "ssh"
    host        = vsphere_virtual_machine.vm.default_ip_address
    user        = var.vm_ssh_user
    private_key = var.ssh_private_key
    timeout     = "10m"
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "set -euxo pipefail",
      # Identify active device and connection
      "PRIMARY_IF=$(nmcli -t -f DEVICE,STATE device | awk -F: '$2==\"connected\"{print $1; exit}')",
      "CONN=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v dev=\"$PRIMARY_IF\" '$2==dev{print $1; exit}')",
      "[ -n \"$CONN\" ] || CONN=$(nmcli -t -f NAME connection show --active | head -n1)",
      # Configure IPv4 manual settings
      "nmcli connection modify \"$CONN\" ipv4.addresses ${var.ipv4_address}/${var.ipv4_netmask} ipv4.gateway ${var.ipv4_gateway} ipv4.method manual autoconnect yes",
      # Optional DNS servers
      "if [ -n \"${join(",", var.dns_server_list)}\" ]; then nmcli connection modify \"$CONN\" ipv4.dns \"${join(",", var.dns_server_list)}\"; fi",
      # Avoid IPv6 interference if not used
      "nmcli connection modify \"$CONN\" ipv6.method ignore || true",
      # Apply changes without dropping SSH if possible
      "nmcli device reapply \"$PRIMARY_IF\" || nmcli connection reload || true",
      # Wait for IP to be applied
      "for i in $(seq 1 30); do ip -4 addr show dev \"$PRIMARY_IF\" | grep -q \"${var.ipv4_address}/\" && break || sleep 2; done",
      "ip -4 addr show dev \"$PRIMARY_IF\"",
    ]
  }

  depends_on = [
    vsphere_virtual_machine.vm,
    null_resource.mount_data_disk
  ]
}
