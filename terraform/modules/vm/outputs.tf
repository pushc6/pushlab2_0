output "vm_name" {
  value = var.prevent_destroy ? vsphere_virtual_machine.vm_protected[0].name : vsphere_virtual_machine.vm_unprotected[0].name
}

output "vm_ip" {
  value = var.prevent_destroy ? vsphere_virtual_machine.vm_protected[0].default_ip_address : vsphere_virtual_machine.vm_unprotected[0].default_ip_address
}

output "network_interfaces" {
  description = "Network interface configuration with MAC addresses for debugging"
  value = concat(
    [{
      name         = "primary"
      network      = var.network
      mac_address  = local.primary_mac
      ipv4_address = var.ipv4_address
    }],
    [for idx, iface in var.additional_interfaces : {
      name         = iface.network_name
      network      = iface.network_name
      mac_address  = local.additional_macs[idx]
      ipv4_address = iface.ipv4_address
    }]
  )
}

output "cloud_init_metadata" {
  description = "Cloud-init metadata YAML (for debugging)"
  value       = local.metadata_yaml
  sensitive   = false
}
