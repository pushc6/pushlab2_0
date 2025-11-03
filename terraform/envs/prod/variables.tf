# Root variables for prod environment root module
variable "vsphere_user" {
  type      = string
  sensitive = true
}
variable "vsphere_password" {
  type      = string
  sensitive = true
}
variable "vsphere_server" { type = string }
variable "allow_unverified_ssl" { type = bool }

variable "datacenter" { type = string }
variable "cluster" { type = string }
variable "datastore" { type = string }
variable "network" { type = string }
variable "vm_folder" { type = string }

# Map of VMs to create
variable "vms" {
  description = "Map of VMs to deploy with per-VM settings"
  type = map(object({
    cpu_count         = number
    memory_mb         = number
    disk_size_gb      = number
    thin_provisioned  = bool
    data_disk_size_gb = number
    data_mount_point  = string
    data_fs_type      = string
    # Static IP settings (when ipv4_address is non-empty)
    ipv4_address = string
    ipv4_netmask = number
    ipv4_gateway = string
    dns_servers  = list(string)
    domain       = string
  }))
  default = {}
}

variable "template_name" { type = string }
variable "vm_ssh_user" { type = string }

variable "ssh_public_key" {
  type        = string
  description = "Public key to push to the VM for key-based SSH"
  default     = ""
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "Private key used by Terraform to SSH to the VM"
}
