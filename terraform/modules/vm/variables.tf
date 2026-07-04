variable "datacenter" {
  type        = string
  description = "vSphere datacenter to deploy into."
}

variable "cluster" {
  type        = string
  description = "vSphere compute cluster (used to resolve the resource pool)."
}

variable "datastore" {
  type        = string
  description = "Datastore for the VM's disks."
}

variable "network" {
  type        = string
  description = "Port group / network name for the primary NIC."
}

variable "vm_folder" {
  type        = string
  description = "vSphere inventory folder for the VM."
}

variable "template_name" {
  type        = string
  description = "Name of the VM template to clone from."
}

variable "vm_name" {
  type        = string
  description = "Name (and default hostname) of the VM."
}

variable "cpu_count" {
  type        = number
  description = "Number of vCPUs."

  validation {
    condition     = var.cpu_count >= 1
    error_message = "cpu_count must be at least 1."
  }
}

variable "memory_mb" {
  type        = number
  description = "Memory in MB."

  validation {
    condition     = var.memory_mb >= 512
    error_message = "memory_mb must be at least 512."
  }
}

variable "disk_size_gb" {
  type        = number
  description = "OS disk size in GB. Never shrunk below the template's base disk (vSphere disallows shrinking on clone)."
}

variable "thin_provisioned" {
  type        = bool
  description = "Whether the VM's disks are thin provisioned."
}

variable "data_disk_size_gb" {
  type        = number
  description = "Size of the additional data disk in GB. 0 disables the data disk."
}

variable "data_mount_point" {
  type        = string
  description = "Mount point for the data disk (e.g. /data)."
}

variable "data_fs_type" {
  type        = string
  description = "Filesystem for the data disk: ext4 or xfs."

  validation {
    condition     = contains(["ext4", "xfs"], var.data_fs_type)
    error_message = "data_fs_type must be one of: ext4, xfs."
  }
}

variable "vm_ssh_user" {
  type        = string
  description = "SSH user for in-guest provisioning/bootstrap."
}

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

  validation {
    condition     = var.ipv4_netmask >= 0 && var.ipv4_netmask <= 32
    error_message = "ipv4_netmask must be a prefix length between 0 and 32."
  }
}

variable "ipv4_gateway" {
  type        = string
  description = "Default IPv4 gateway for the VM."
  default     = ""
}

# Primary-interface IPv6 settings (mirror the fields available on
# additional_interfaces). All optional. accept_ra=null leaves the
# netplan/NM default in place.
variable "ipv6_address" {
  type        = string
  description = "Static IPv6 address (e.g. fd00:...::254/64) for the primary NIC. Empty = none."
  default     = ""
}

variable "ipv6_gateway" {
  type        = string
  description = "IPv6 default gateway (typically a router link-local fe80::) on the primary NIC. Empty = none."
  default     = ""
}

variable "accept_ra" {
  type        = bool
  description = "Per-interface RA acceptance on the primary. true on the uplink; false to suppress unwanted RAs. null leaves it unset."
  default     = null
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
