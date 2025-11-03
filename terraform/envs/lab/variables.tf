# Root variables for lab environment root module
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

# Map of VMs (optional for lab)
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
  }))
  default = {}
}

variable "template_name" { type = string }

# Single-VM fallback variables
variable "vm_name" { type = string }
variable "cpu_count" { type = number }
variable "memory_mb" { type = number }
variable "disk_size_gb" { type = number }
variable "thin_provisioned" { type = bool }
variable "data_disk_size_gb" { type = number }
variable "data_mount_point" { type = string }
variable "data_fs_type" { type = string }

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
