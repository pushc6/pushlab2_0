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
  # Ensure we never shrink the OS disk below the template's base disk size (vSphere disallows shrinking on clone)
  effective_os_disk_size_gb = max(var.disk_size_gb, try(data.vsphere_virtual_machine.template.disks[0].size, var.disk_size_gb))

  # ============================================================================
  # MAC ADDRESS GENERATION
  # ============================================================================
  # Generate deterministic MAC addresses using MD5 hash of VM name + interface
  # VMware manual MAC range: 00:50:56:00:00:00 to 00:50:56:3F:FF:FF
  # First byte of last 3 octets must be 0-63 (0x00-0x3F)

  # Primary interface MAC
  primary_mac_hash = md5("${var.vm_name}-primary")
  primary_mac = format("00:50:56:%02x:%02x:%02x",
    parseint(substr(local.primary_mac_hash, 0, 2), 16) % 64, # 0-63 range
    parseint(substr(local.primary_mac_hash, 2, 2), 16),
    parseint(substr(local.primary_mac_hash, 4, 2), 16)
  )

  # Additional interface MACs - use network name in hash for stability
  additional_macs = [
    for idx, iface in var.additional_interfaces : format("00:50:56:%02x:%02x:%02x",
      parseint(substr(md5("${var.vm_name}-${iface.network_name}"), 0, 2), 16) % 64,
      parseint(substr(md5("${var.vm_name}-${iface.network_name}"), 2, 2), 16),
      parseint(substr(md5("${var.vm_name}-${iface.network_name}"), 4, 2), 16)
    )
  ]

  # All MACs in order (primary first, then additional)
  all_macs = concat([local.primary_mac], local.additional_macs)

  # ============================================================================
  # CLOUD-INIT NETWORK CONFIGURATION (MAC-based matching)
  # ============================================================================
  # Uses MAC address matching instead of interface names (eth0, eth1) because
  # Linux interface enumeration order is not guaranteed to match vSphere NIC order
  #
  # Gateway logic: If any additional interface has ipv4_gateway set, use that.
  # Otherwise, use the primary interface gateway. Only one default route allowed.

  # Check if any additional interface has a gateway configured
  additional_has_gateway = anytrue([
    for iface in var.additional_interfaces : iface.ipv4_gateway != "" && iface.ipv4_gateway != null
  ])

  # Primary interface only gets gateway if no additional interface has one
  effective_primary_gateway = local.additional_has_gateway ? "" : var.ipv4_gateway

  metadata_yaml = var.use_cloud_init && length(var.ipv4_address) > 0 ? join("\n", concat(
    ["local-hostname: ${var.vm_name}"],
    ["network:"],
    ["  version: 2"],
    ["  ethernets:"],
    # Primary interface
    ["    primary:"],
    ["      match:"],
    ["        macaddress: \"${local.primary_mac}\""],
    ["      dhcp4: false"],
    ["      addresses:"],
    ["        - ${var.ipv4_address}/${var.ipv4_netmask}"],
    # Use modern routes syntax instead of deprecated gateway4
    length(local.effective_primary_gateway) > 0 ? [
      "      routes:",
      "        - to: default",
      "          via: ${local.effective_primary_gateway}"
    ] : [],
    length(var.dns_server_list) > 0 ? concat(
      ["      nameservers:"],
      ["        addresses:"],
      [for ns in var.dns_server_list : "          - ${ns}"]
    ) : [],
    # Additional interfaces
    flatten([
      for idx, iface in var.additional_interfaces : concat(
        ["    ${replace(lower(iface.network_name), " ", "-")}:"],
        ["      match:"],
        ["        macaddress: \"${local.additional_macs[idx]}\""],
        ["      dhcp4: false"],
        ["      addresses:"],
        ["        - ${iface.ipv4_address}/${iface.ipv4_netmask}"],
        # Use modern routes syntax for gateway on additional interfaces
        iface.ipv4_gateway != "" && iface.ipv4_gateway != null ? [
          "      routes:",
          "        - to: default",
          "          via: ${iface.ipv4_gateway}"
        ] : []
      )
    ])
  )) : ""

  # Cloud-init userdata for hostname and SSH key injection
  userdata_yaml = var.use_cloud_init && length(var.ipv4_address) > 0 ? join("\n", concat(
    ["#cloud-config"],
    ["fqdn: ${var.vm_name}.${var.domain}"],
    ["manage_etc_hosts: true"],
    # Inject SSH public key if provided
    length(var.ssh_public_key) > 0 ? [
      "users:",
      "  - name: root",
      "    ssh_authorized_keys:",
      "      - ${var.ssh_public_key}"
    ] : []
  )) : ""

  cloud_init_extra = var.use_cloud_init && length(var.ipv4_address) > 0 ? {
    "guestinfo.metadata"          = base64encode(local.metadata_yaml),
    "guestinfo.metadata.encoding" = "base64",
    "guestinfo.userdata"          = base64encode(local.userdata_yaml),
    "guestinfo.userdata.encoding" = "base64"
  } : {}

  # Common VM configuration
  vm_config = {
    name             = var.vm_name
    folder           = var.vm_folder
    resource_pool_id = data.vsphere_compute_cluster.clu.resource_pool_id
    datastore_id     = data.vsphere_datastore.ds.id
    num_cpus         = var.cpu_count
    memory           = var.memory_mb
    guest_id         = data.vsphere_virtual_machine.template.guest_id
    firmware         = data.vsphere_virtual_machine.template.firmware
    scsi_type        = data.vsphere_virtual_machine.template.scsi_type
  }

  network_interface_config = {
    network_id   = data.vsphere_network.net.id
    adapter_type = data.vsphere_virtual_machine.template.network_interface_types[0]
  }

  os_disk_config = {
    label            = "osdisk"
    size             = local.effective_os_disk_size_gb
    thin_provisioned = var.thin_provisioned
  }

  data_disk_config = {
    label            = "datadisk"
    size             = var.data_disk_size_gb
    thin_provisioned = var.thin_provisioned
    unit_number      = 1
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

data "vsphere_network" "additional" {
  count         = length(var.additional_interfaces)
  name          = var.additional_interfaces[count.index].network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# State moves to keep addresses stable across refactors and when toggling protection
# 1) Migrate from legacy single resource (vm) to the new unprotected resource name
moved {
  from = vsphere_virtual_machine.vm
  to   = vsphere_virtual_machine.vm_unprotected[0]
}

# 2) One-time toggle (unprotected -> protected) to avoid replacement when enabling protection
# Note: Instance-specific moves are defined at the root (env) to avoid affecting
# other VMs that remain unprotected.

resource "vsphere_virtual_machine" "vm_unprotected" {
  count            = var.prevent_destroy ? 0 : 1
  name             = local.vm_config.name
  folder           = local.vm_config.folder
  resource_pool_id = local.vm_config.resource_pool_id
  datastore_id     = local.vm_config.datastore_id

  num_cpus  = local.vm_config.num_cpus
  memory    = local.vm_config.memory
  guest_id  = local.vm_config.guest_id
  firmware  = local.vm_config.firmware
  scsi_type = local.vm_config.scsi_type

  # Prevent reboots when extra_config changes - cloud-init only runs on first boot
  extra_config_reboot_required = false

  # Primary network interface with static MAC for cloud-init matching
  network_interface {
    network_id     = local.network_interface_config.network_id
    adapter_type   = local.network_interface_config.adapter_type
    use_static_mac = true
    mac_address    = local.primary_mac
  }

  # Additional network interfaces with static MACs
  dynamic "network_interface" {
    for_each = { for idx, net in data.vsphere_network.additional : idx => net }
    content {
      network_id     = network_interface.value.id
      adapter_type   = local.network_interface_config.adapter_type
      use_static_mac = true
      mac_address    = local.additional_macs[network_interface.key]
    }
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
    label            = local.os_disk_config.label
    size             = local.os_disk_config.size
    thin_provisioned = local.os_disk_config.thin_provisioned
  }

  dynamic "disk" {
    for_each = var.data_disk_size_gb > 0 ? [1] : []
    content {
      label            = local.data_disk_config.label
      size             = local.data_disk_config.size
      thin_provisioned = local.data_disk_config.thin_provisioned
      unit_number      = local.data_disk_config.unit_number
    }
  }

  wait_for_guest_net_timeout = 600
  wait_for_guest_ip_timeout  = 600

  lifecycle {
    # Prevent unnecessary replacement when the source template changes
    # for already-cloned VMs. The VM exists and changing the template
    # would force a replace, which we do not want.
    ignore_changes = [clone]
  }
}

resource "vsphere_virtual_machine" "vm_protected" {
  count            = var.prevent_destroy ? 1 : 0
  name             = local.vm_config.name
  folder           = local.vm_config.folder
  resource_pool_id = local.vm_config.resource_pool_id
  datastore_id     = local.vm_config.datastore_id

  num_cpus  = local.vm_config.num_cpus
  memory    = local.vm_config.memory
  guest_id  = local.vm_config.guest_id
  firmware  = local.vm_config.firmware
  scsi_type = local.vm_config.scsi_type

  # Prevent reboots when extra_config changes - cloud-init only runs on first boot
  extra_config_reboot_required = false

  # Primary network interface with static MAC for cloud-init matching
  network_interface {
    network_id     = local.network_interface_config.network_id
    adapter_type   = local.network_interface_config.adapter_type
    use_static_mac = true
    mac_address    = local.primary_mac
  }

  # Additional network interfaces with static MACs
  dynamic "network_interface" {
    for_each = { for idx, net in data.vsphere_network.additional : idx => net }
    content {
      network_id     = network_interface.value.id
      adapter_type   = local.network_interface_config.adapter_type
      use_static_mac = true
      mac_address    = local.additional_macs[network_interface.key]
    }
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
    label            = local.os_disk_config.label
    size             = local.os_disk_config.size
    thin_provisioned = local.os_disk_config.thin_provisioned
  }

  dynamic "disk" {
    for_each = var.data_disk_size_gb > 0 ? [1] : []
    content {
      label            = local.data_disk_config.label
      size             = local.data_disk_config.size
      thin_provisioned = local.data_disk_config.thin_provisioned
      unit_number      = local.data_disk_config.unit_number
    }
  }

  wait_for_guest_net_timeout = 600
  wait_for_guest_ip_timeout  = 600

  lifecycle {
    prevent_destroy = true
    # Prevent unnecessary replacement when the source template changes
    # for already-cloned VMs. The VM exists and changing the template
    # would force a replace, which we explicitly want to avoid.
    ignore_changes = [clone]
  }
}

locals {
  vm_id         = var.prevent_destroy ? vsphere_virtual_machine.vm_protected[0].id : vsphere_virtual_machine.vm_unprotected[0].id
  vm_default_ip = var.prevent_destroy ? vsphere_virtual_machine.vm_protected[0].default_ip_address : vsphere_virtual_machine.vm_unprotected[0].default_ip_address
}
