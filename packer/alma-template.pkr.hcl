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
  default     = "VLAN 70 - DMZ"
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

# New: Public key to embed into the template for key-based SSH
variable "ssh_public_key" {
  type        = string
  description = "SSH public key to add to /root/.ssh/authorized_keys in the template (optional)"
  default     = ""
}

variable "ssh_private_key_file" {
  type        = string
  description = "Path to the private key matching the SSH public key injected via kickstart. Used by Packer to connect."
  default     = ""
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
    "inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/generated.ks",
    "<spacebar>",
    "ip=dhcp",
    "<spacebar>",
    "inst.ksdevice=link",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]

  # HTTP server for serving kickstart file
  http_directory = "http"
  http_port_min  = 8080
  http_port_max  = 8080

  # SSH configuration for post-install
  ssh_username         = "root"
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
    source      = "scripts/"
    destination = "/tmp/"
  }

  # Install SSH public key into root authorized_keys if provided
  provisioner "shell" {
    environment_vars = [
      "PUBKEY=${var.ssh_public_key}"
    ]
    inline = [
      "set -euxo pipefail",
      "if [ -n \"$PUBKEY\" ]; then",
      "  install -d -m 700 /root/.ssh",
      "  touch /root/.ssh/authorized_keys",
      "  chmod 600 /root/.ssh/authorized_keys",
      "  grep -qxF \"$PUBKEY\" /root/.ssh/authorized_keys || echo \"$PUBKEY\" >> /root/.ssh/authorized_keys",
      "fi"
    ]
  }

  # Run cleanup and optimization scripts
  provisioner "shell" {
    scripts = [
      "scripts/update-system.sh",
      "scripts/install-packages.sh",
      "scripts/configure-services.sh",
      "scripts/cleanup-template.sh",
      "scripts/validate-template.sh"
    ]
    execute_command = "chmod +x {{ .Path }}; {{ .Path }}"
  }

  # Optionally harden SSH to key-only if a key was installed
  provisioner "shell" {
    environment_vars = [
      "PUBKEY=${var.ssh_public_key}"
    ]
    inline = [
      "set -euxo pipefail",
      "if [ -n \"$PUBKEY\" ]; then",
      "  sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
      "  sed -i -E 's/^#?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config",
      "  systemctl restart sshd || true",
      "fi"
    ]
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo 'Template build completed successfully'",
      "systemctl enable regenerate-ssh-keys.service || true"
    ]
  }
}
