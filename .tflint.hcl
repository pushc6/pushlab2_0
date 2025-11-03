plugin "vsphere" {
  enabled = true
  version = "0.6.3"
  source  = "github.com/terraform-linters/tflint-ruleset-vsphere"
}

config {
  module = true
}
