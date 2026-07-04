tflint {
  required_version = ">= 0.50"
}

config {
  call_module_type = "all"
}

# Core Terraform rules (bundled ruleset): unused declarations, missing
# version constraints, deprecated syntax, etc.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
