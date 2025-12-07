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

  # Construct the primary interface config
  primary_iface_config = length(var.ipv4_address) > 0 ? {
    eth0 = {
      dhcp4       = false
      addresses   = [format("%s/%d", var.ipv4_address, var.ipv4_netmask)]
      gateway4    = var.ipv4_gateway
      nameservers = { addresses = var.dns_server_list }
    }
  } : {}

  # Construct additional interfaces config
  additional_iface_config = {
    for idx, iface in var.additional_interfaces : "eth${idx + 1}" => {
      dhcp4     = false
      addresses = [format("%s/%d", iface.ipv4_address, iface.ipv4_netmask)]
    }
  }

  network_config_ethernets = merge(local.primary_iface_config, local.additional_iface_config)

  cloud_init_extra = var.use_cloud_init && length(local.network_config_ethernets) > 0 ? {
    "guestinfo.metadata" = base64encode(yamlencode({
      local_hostname = var.vm_name,
      network = {
        version   = 2,
        ethernets = local.network_config_ethernets
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

  network_interface {
    network_id   = local.network_interface_config.network_id
    adapter_type = local.network_interface_config.adapter_type
  }

  dynamic "network_interface" {
    for_each = data.vsphere_network.additional
    content {
      network_id   = network_interface.value.id
      adapter_type = local.network_interface_config.adapter_type
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

  network_interface {
    network_id   = local.network_interface_config.network_id
    adapter_type = local.network_interface_config.adapter_type
  }

  dynamic "network_interface" {
    for_each = data.vsphere_network.additional
    content {
      network_id   = network_interface.value.id
      adapter_type = local.network_interface_config.adapter_type
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
