variable "datacenter" { type = string }

variable "cluster" { type = string }

variable "datastore" { type = string }

variable "network" { type = string }

variable "vm_folder" { type = string }

variable "template_name" { type = string }

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
  description = "Public key to add to the VM's authorized_keys during bootstrap. If empty, no bootstrap occurs."
  default     = ""
}

variable "ssh_private_key" {
  type        = string
  sensitive   = true
  description = "Private key material used for SSH connections (PEM/OPENSSH)."
}

# Optional static IP customization (when ipv4_address is non-empty)
variable "ipv4_address" {
  type        = string
  description = "Static IPv4 address to assign to the primary NIC. If empty, DHCP is used."
  default     = ""
}

variable "ipv4_netmask" {
  type        = number
  description = "IPv4 netmask (prefix length), e.g., 24 for 255.255.255.0."
  default     = 24
}

variable "ipv4_gateway" {
  type        = string
  description = "Default IPv4 gateway for the VM."
  default     = ""
}

variable "dns_server_list" {
  type        = list(string)
  description = "List of DNS server IPs for guest customization."
  default     = []
}

variable "domain" {
  type        = string
  description = "Domain name to set in guest customization (also used for DNS suffix)."
  default     = "localdomain"
}

# Optional: use vSphere Guest Customization instead of in-guest nmcli for static IP
variable "use_vsphere_customization" {
  type        = bool
  description = "If true, sets static IP/DNS via vSphere guest customization at clone time. If false, in-guest nmcli is used."
  default     = true
}

variable "use_cloud_init" {
  type        = bool
  description = "If true, pass cloud-init data via VMware guestinfo (metadata/userdata/networkconfig) to configure static IP and hostname. Recommended for modern Linux."
  default     = true
}

# Safety brake to prevent accidental destroy/recreate of critical VMs.
variable "prevent_destroy" {
  type        = bool
  description = "If true, set lifecycle.prevent_destroy on the VM resource to block destroy/recreate operations."
  default     = false
}

variable "additional_interfaces" {
  type = list(object({
    network_name = string
    ipv4_address = string
    ipv4_netmask = number
    ipv4_gateway = optional(string, "")
    # IPv6 fields (all optional). Set ipv6_gateway on the same interface as
    # ipv4_gateway when you want a default IPv6 route through the same router.
    # Use the router's link-local (fe80::) address; on-link is implied.
    # accept_ra=true lets the kernel learn the GUA prefix from Router
    # Advertisements (typical for ISP-delegated /64s).
    ipv6_address = optional(string, "")
    ipv6_gateway = optional(string, "")
    # Nullable. When unset, no `accept-ra:` line is emitted (kernel default
    # applies). Set true on the uplink, false on the others to explicitly
    # suppress unwanted GUA assignment from non-default-router VLANs.
    accept_ra = optional(bool)
  }))
  description = "List of additional network interfaces. Set ipv4_gateway (and optionally ipv6_gateway) on ONE interface for default route (use routes syntax, not gateway4)."
  default     = []

  validation {
    condition = length([
      for iface in var.additional_interfaces : iface.ipv4_gateway
      if iface.ipv4_gateway != "" && iface.ipv4_gateway != null
    ]) <= 1
    error_message = "Only one additional interface can have ipv4_gateway set. Multiple default gateways cause routing conflicts."
  }

  validation {
    condition = length([
      for iface in var.additional_interfaces : iface.ipv6_gateway
      if iface.ipv6_gateway != "" && iface.ipv6_gateway != null
    ]) <= 1
    error_message = "Only one additional interface can have ipv6_gateway set."
  }
}
