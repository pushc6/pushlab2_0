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
    data_disk_size_gb = optional(number)
    data_mount_point  = optional(string)
    data_fs_type      = optional(string)
    # Optional override for vSphere network (defaults to root var.network)
    network = optional(string)
    # Optional desired hostname inside the guest (defaults to VM key)
    hostname = optional(string)
    # Optional safety brake: block destroy/recreate of this VM
    prevent_destroy = optional(bool)
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
  default     = ""
}

# Optional: path to a private key file. If provided, the file contents will be used
# instead of ssh_private_key. This keeps secrets out of tfvars.
variable "ssh_private_key_file" {
  type        = string
  description = "Path to the SSH private key file used by Terraform to SSH to the VM"
  default     = ""
}
