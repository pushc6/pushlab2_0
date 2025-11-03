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

data "vsphere_datacenter" "dc" { name = var.datacenter }

data "vsphere_datastore" "ds" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

// Deprecated: this env-local module is no longer used. See ../../../../modules/vm
name = var.cluster
