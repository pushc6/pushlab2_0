output "vm_name" {
	value = var.prevent_destroy ? vsphere_virtual_machine.vm_protected[0].name : vsphere_virtual_machine.vm_unprotected[0].name
}
output "vm_ip" {
	value = var.prevent_destroy ? vsphere_virtual_machine.vm_protected[0].default_ip_address : vsphere_virtual_machine.vm_unprotected[0].default_ip_address
}
