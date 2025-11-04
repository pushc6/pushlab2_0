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

locals {
  cloud_init_extra = var.use_cloud_init && length(var.ipv4_address) > 0 ? {
    "guestinfo.metadata" = base64encode(yamlencode({
      local_hostname = var.vm_name,
      network = {
        version = 2,
        ethernets = {
          eth0 = {
            dhcp4       = false,
            addresses   = [format("%s/%d", var.ipv4_address, var.ipv4_netmask)],
            gateway4    = var.ipv4_gateway,
            nameservers = { addresses = var.dns_server_list }
          }
        }
      }
    })),
    "guestinfo.metadata.encoding" = "base64",
    "guestinfo.userdata" = base64encode(join("\n", [
      "#cloud-config",
      "fqdn: ${var.vm_name}.${var.domain}",
      "manage_etc_hosts: true"
    ])),
    "guestinfo.userdata.encoding" = "base64"
  } : {}
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

      dynamic "customize" {
        for_each = var.use_vsphere_customization && !var.use_cloud_init && (length(var.ipv4_address) > 0 || length(var.dns_server_list) > 0) ? [1] : []
        content {
          timeout = 600
          linux_options {
            host_name = var.vm_name
            domain    = var.domain
          }

          network_interface {
            ipv4_address = var.ipv4_address
            ipv4_netmask = var.ipv4_netmask
          }

          ipv4_gateway    = var.ipv4_gateway
          dns_server_list = var.dns_server_list
        }
      }
    }
  }

  # Cloud-init guestinfo data (if enabled)
  extra_config = local.cloud_init_extra

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
      # Identify OS-related base disks to exclude (/, /boot, /boot/efi)
      "ROOT_SRC=$(findmnt -no SOURCE /)",
      "ROOT_BASE=$(lsblk -no PKNAME \"$ROOT_SRC\" 2>/dev/null || true)",
      "BOOT_SRC=$(findmnt -no SOURCE /boot 2>/dev/null || true)",
      "BOOT_BASE=$( [ -n \"$BOOT_SRC\" ] && lsblk -no PKNAME \"$BOOT_SRC\" 2>/dev/null || true)",
      "EFI_SRC=$(findmnt -no SOURCE /boot/efi 2>/dev/null || true)",
      "EFI_BASE=$( [ -n \"$EFI_SRC\" ] && lsblk -no PKNAME \"$EFI_SRC\" 2>/dev/null || true)",
      "EXCLUDE=$(printf '%s\\n' \"$ROOT_BASE\" \"$BOOT_BASE\" \"$EFI_BASE\" | awk 'NF' | sort -u | tr '\\n' ' ')",
      # Identify the data disk by exact size match (in bytes) and not in EXCLUDE
      "DATA_GB=${var.data_disk_size_gb}",
      "DATA_BYTES=$((DATA_GB * 1024 * 1024 * 1024))",
      "CANDIDATES=$(lsblk -bdn -o NAME,SIZE,TYPE | awk -v sz=\"$DATA_BYTES\" '$3==\"disk\" && $2==sz {print $1}')",
      "TARGET_DISK=",
      "for d in $CANDIDATES; do skip=0; for e in $EXCLUDE; do [ \"$d\" = \"$e\" ] && skip=1 && break; done; [ $skip -eq 0 ] && TARGET_DISK=$d && break; done",
      "if [ -z \"$TARGET_DISK\" ]; then echo 'ERROR: Could not identify data disk safely (size match not found or conflicts). Aborting.'; exit 1; fi",
      "DEV=/dev/$TARGET_DISK",
      "PART=$(printf '%s1' \"$DEV\")",
      # Safety: ensure no existing mounts originate from this disk
      "if lsblk -nr \"$DEV\" | awk 'NF && length($7)>0 {exit 1}'; then true; else echo 'ERROR: Target disk or its partitions have active mountpoints; aborting.'; exit 1; fi",
      # Wait for device
      "for i in {1..60}; do [ -b \"$DEV\" ] && break || sleep 2; done",
      # Ensure mkfs tools
      "if [ \"${var.data_fs_type}\" = xfs ]; then command -v mkfs.xfs >/dev/null 2>&1 || timeout 180 dnf -y install xfsprogs || true; fi",
      "if [ \"${var.data_fs_type}\" = ext4 ]; then command -v mkfs.ext4 >/dev/null 2>&1 || timeout 180 dnf -y install e2fsprogs || true; fi",
      "command -v wipefs >/dev/null 2>&1 || timeout 180 dnf -y install util-linux || true",
      # If already mounted at the mount point, exit
      "MP=$(findmnt -rn -T ${var.data_mount_point} -o TARGET 2>/dev/null || true)",
      "if [ \"$MP\" = \"${var.data_mount_point}\" ]; then echo 'Already mounted'; exit 0; fi",
      # Detect current filesystem
      "FSTYPE=$(lsblk -no FSTYPE \"$PART\" 2>/dev/null | head -n1 || lsblk -no FSTYPE \"$DEV\" | head -n1 || true)",
      "if [ -z \"$FSTYPE\" ] || [ \"$FSTYPE\" != \"${var.data_fs_type}\" ]; then \\",
      "  umount -lf \"$DEV\" 2>/dev/null || true; \\",
      "  for p in \"$DEV?*\"; do [ -b \"$p\" ] && umount -lf \"$p\" || true; done; \\",
      "  sfdisk --delete \"$DEV\" || true; \\",
      "  partx -d \"$DEV\" || true; \\",
      "  wipefs -fa \"$DEV\" || true; \\",
      "  udevadm settle || true; sleep 2; \\",
      "  printf ',,L,*\n' | sfdisk \"$DEV\" || true; \\",
      "  partprobe \"$DEV\" || true; udevadm settle || true; \\",
      "  for i in {1..30}; do [ -b \"$PART\" ] && break || sleep 1; done; \\",
      "  if [ \"${var.data_fs_type}\" = xfs ]; then \\",
      "    mkfs.xfs -f \"$PART\"; \\",
      "  elif [ \"${var.data_fs_type}\" = ext4 ]; then \\",
      "    mkfs.ext4 -F \"$PART\"; \\",
      "  else \\",
      "    mkfs -t ${var.data_fs_type} \"$PART\"; \\",
      "  fi; \\",
      "fi",
      "mkdir -p ${var.data_mount_point}",
      "udevadm settle || true; sleep 1",
      "UUID=$(blkid -s UUID -o value \"$PART\" 2>/dev/null || true)",
      "if [ -z \"$UUID\" ]; then UUID=$(lsblk -no UUID \"$PART\" | head -n1 || true); fi",
      "LINE=\"UUID=$UUID ${var.data_mount_point} ${var.data_fs_type} defaults,nofail 0 2\"",
      "awk '$2 != \"${var.data_mount_point}\" {print}' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab",
      "grep -qxF \"$LINE\" /etc/fstab || echo \"$LINE\" >> /etc/fstab",
      "systemctl daemon-reload || true",
      "mount -a",
      "findmnt -rn -T ${var.data_mount_point}"
    ]
  }
}

# Optional in-guest static IP configuration (fallback when not using vSphere customization or cloud-init)
resource "null_resource" "configure_static_ip" {
  count = length(var.ipv4_address) > 0 && !var.use_vsphere_customization && !var.use_cloud_init ? 1 : 0

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
      "PRIMARY_IF=$(nmcli -t -f DEVICE,STATE device | awk -F: '$2==\"connected\"{print $1; exit}')",
      "CONN=$(nmcli -t -f NAME,DEVICE connection show --active | awk -F: -v dev=\"$PRIMARY_IF\" '$2==dev{print $1; exit}')",
      "[ -n \"$CONN\" ] || CONN=$(nmcli -t -f NAME connection show --active | head -n1)",
      "nmcli connection modify \"$CONN\" ipv4.addresses ${var.ipv4_address}/${var.ipv4_netmask} ipv4.gateway ${var.ipv4_gateway} ipv4.method manual autoconnect yes",
      "if [ -n \"${join(",", var.dns_server_list)}\" ]; then nmcli connection modify \"$CONN\" ipv4.dns \"${join(",", var.dns_server_list)}\" ipv4.ignore-auto-dns yes; fi",
      "nmcli connection modify \"$CONN\" ipv6.method ignore || true",
      "( sleep 2; nmcli device reapply \"$PRIMARY_IF\" || nmcli connection up \"$CONN\" || nmcli connection reload ) >/dev/null 2>&1 &",
      "echo 'Static IP will apply shortly; connection may briefly drop.'",
    ]
  }

  depends_on = [
    vsphere_virtual_machine.vm,
    null_resource.mount_data_disk
  ]
}
