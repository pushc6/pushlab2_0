packer {
  required_plugins {
    vsphere = {
      version = ">= 1.2.3"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

# Variable definitions
variable "vcenter_server" {
  type        = string
  description = "vCenter server FQDN or IP"
}

variable "vcenter_username" {
  type        = string
  description = "vCenter username"
}

variable "vcenter_password" {
  type        = string
  description = "vCenter password"
  sensitive   = true
}

variable "datacenter" {
  type        = string
  description = "vSphere datacenter"
  default     = "Push Datacenter"
}

variable "cluster" {
  type        = string
  description = "vSphere cluster"
  default     = "Lab Cluster"
}

variable "datastore" {
  type        = string
  description = "vSphere datastore"
  default     = "ssd-local"
}

variable "network" {
  type        = string
  description = "vSphere network"
  default     = "VLAN 80 - App"
}

variable "template_name" {
  type        = string
  description = "Template name"
  default     = "almalinux-10-minimal-template"
}

variable "alma_iso_url" {
  type        = string
  description = "AlmaLinux 10 ISO URL"
  default     = "https://repo.almalinux.org/almalinux/10/isos/x86_64/AlmaLinux-10.0-x86_64-boot.iso"
}

variable "ssh_private_key_file" {
  type        = string
  description = "Path to the private key matching the SSH public key injected via kickstart. Used by Packer to connect."
  default     = ""
}

# Path to the SSH public key file to inject during OS install (no wrapper script required)
variable "ssh_public_key_file" {
  type        = string
  description = "Path to the SSH public key file to add to /root/.ssh/authorized_keys via kickstart"
  default     = ""
}

# Optional: alternatively provide the SSH public key content directly
variable "ssh_public_key" {
  type        = string
  description = "SSH public key content to inject if not using ssh_public_key_file"
  default     = null
}

locals {
  # Base64-encoded public key for safe transport on the kernel cmdline
  ssh_public_key_b64 = var.ssh_public_key_file != "" ? base64encode(trimspace(file(var.ssh_public_key_file))) : (
    var.ssh_public_key != null && var.ssh_public_key != "" ? base64encode(trimspace(var.ssh_public_key)) : ""
  )
}

# Build configuration
source "vsphere-iso" "almalinux" {
  # vCenter connection
  vcenter_server      = var.vcenter_server
  username            = var.vcenter_username
  password            = var.vcenter_password
  insecure_connection = true

  # vSphere infrastructure
  datacenter = var.datacenter
  cluster    = var.cluster
  datastore  = var.datastore
  folder     = "Templates"

  # VM configuration
  vm_name              = var.template_name
  # vSphere 8: prefer a modern Linux guest type; AlmaLinux 10 aligns closest with RHEL9
  guest_os_type        = "rhel9_64Guest"
  firmware             = "efi"
  CPUs                 = 2
  RAM                  = 4096
  RAM_reserve_all      = false
  disk_controller_type = ["pvscsi"]
  
  storage {
    disk_size             = 40960
    disk_thin_provisioned = true
  }

  network_adapters {
    network      = var.network
    network_card = "vmxnet3"
  }

  # ISO configuration
  iso_url      = var.alma_iso_url
  iso_checksum = "file:https://repo.almalinux.org/almalinux/10/isos/x86_64/CHECKSUM"

  # Boot configuration for kickstart automation
  boot_wait = "20s"
  boot_command = [
    "e",
    "<down><down>",
    "<leftCtrlOn>e<leftCtrlOff>",
    "<spacebar>",
    "biosdevname=0",
    "<spacebar>",
    "net.ifnames=0",
    "<spacebar>",
    "inst.text",
    "<spacebar>",
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/almalinux-10.vsphere-x86_64.ks",
    "<spacebar>",
    "ip=dhcp",
    "<spacebar>",
    "inst.ksdevice=link",
    "<spacebar>",
    "pubkey_b64=${local.ssh_public_key_b64}",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]

  # HTTP server for serving kickstart file
  http_directory = "${path.root}/http"
  http_port_min  = 8080
  http_port_max  = 8080

  # SSH configuration for post-install
  ssh_username         = "root"
  # Use explicit key file; disable SSH agent auth per user preference
  ssh_agent_auth       = false
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = "45m"
  ssh_port             = 22

  # VM lifecycle
  shutdown_command = "shutdown -P now"
  shutdown_timeout = "10m"
  
  # Convert to template
  convert_to_template = true
  create_snapshot     = false
}

# Build process
build {
  sources = ["source.vsphere-iso.almalinux"]

  # Upload additional files
  provisioner "file" {
    source      = "${path.root}/scripts/"
    destination = "/tmp/"
  }

  # Run cleanup and optimization scripts
  provisioner "shell" {
    scripts = [
      "${path.root}/scripts/update-system.sh",
      "${path.root}/scripts/install-packages.sh",
      "${path.root}/scripts/configure-services.sh",
      "${path.root}/scripts/cleanup-template.sh",
      "${path.root}/scripts/validate-template.sh"
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Path }}"
  }

  # SSH hardening handled in kickstart %post

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo 'Template build completed successfully'",
      "systemctl enable regenerate-ssh-keys.service || true"
    ]
  }
}
