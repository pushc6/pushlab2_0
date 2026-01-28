# OPNsense Firewall Role

Automatically manages **granular** OPNsense firewall rules for Terraform-created hosts with specific source-destination combinations.

## Requirements

- `puzzle.opnsense` collection
- OPNsense API enabled with valid credentials
- Management access from Ansible controller to OPNsense API

## Role Variables

### Required (from Gitea Secrets)
- `opnsense_api_key`: API key for OPNsense
- `opnsense_api_secret`: API secret for OPNsense

### Optional
- `opnsense_api_url`: API endpoint (default: `https://{{ ansible_host }}`)
- `opnsense_validate_certs`: Validate SSL certs (default: `false`)
- `firewall_defaults`: Default settings for firewall rules

### Custom Aliases

Define reusable aliases in `group_vars/opnsense/vars.yml`:

```yaml
opnsense_aliases:
  # Host aliases (IP addresses)
  - name: "management_hosts"
    type: host
    content:
      - "10.37.50.10"
      - "10.37.80.5"
    description: "Management workstations"
    
  # Network aliases (CIDR ranges)
  - name: "internal_networks"
    type: network
    content:
      - "10.37.0.0/16"
      - "172.16.0.0/12"
    description: "Internal networks"
    
  # Port aliases
  - name: "web_ports"
    type: port
    content: ["80", "443", "8080"]
    description: "Web service ports"
    
  # URL tables (dynamic lists)
  - name: "blocklist"
    type: urltable
    content:
      - "https://blocklist.example.com/ips.txt"
    description: "Threat intelligence feed"
    refresh_frequency: 1  # Days
```

**Supported alias types:**
- `host`: Single IP or list of IPs
- `network`: CIDR networks
- `port`: Port numbers or ranges
- `url`: Single URL
- `urltable`: URL containing list of IPs (auto-refreshes)

### Firewall Rules Configuration

Rules are defined in `group_vars/opnsense/vars.yml`:

```yaml
terraform_host_firewall_rules:
  - name: "SSH from Ansible to Terraform hosts"
    description: "Allow Ansible controller to SSH to all Terraform hosts"
    source: "semaphore.localdomain"  # Can be IP, hostname, or OPNsense alias
    destination: "terraform_hosts"  # Auto-created alias of all Terraform hosts
    protocol: tcp
    port: 22
    interface: lan  # Specify interface (lan, wan, dmz, opt1, vlan10, etc.)
    log: false      # Optional, defaults to firewall_defaults.log
```

**Supported interface values:**
- `lan` - LAN interface
- `wan` - WAN interface  
- `dmz` - DMZ interface
- `opt1`, `opt2`, etc. - Optional interfaces
- `vlan10`, `vlan20`, etc. - VLAN interfaces
- Any custom interface name from your OPNsense config
- **Array of interfaces** - Apply same rule to multiple interfaces

**Single vs. Multiple Interfaces:**
```yaml
# Single interface (string)
interface: lan

# Multiple interfaces (array) - creates separate rule for each
interface:
  - lan
  - dmz
  - vlan10
```

**Multi-interface examples:**
```yaml
# WAN to DMZ (public access to web server)
- name: "HTTPS from Internet"
  source: any
  destination: "webserver"
  protocol: tcp
  port: 443
  interface: wan

# DMZ to LAN (database access)  
- name: "DMZ to Database"
  source: "dmz_servers"
  destination: "db_server"
  protocol: tcp
  port: 5432
  interface: dmz
```

### Conditional Rules

Skip rules when not needed using the `when` parameter:

```yaml
# Skip same-subnet rules
- name: "Same subnet access"
  source: "10.37.70.5"
  destination: "10.37.70.10"
  protocol: tcp
  port: 22
  interface: VLAN70DMZ
  when: false  # Skip - same subnet, no explicit rule needed

# Conditional based on inventory
- name: "Cross-VLAN access"
  source: "management_vlan"
  destination: "app_servers"
  protocol: tcp
  port: 443
  interface: VLAN80App
  when: "{{ groups['app_servers'] is defined and groups['app_servers'] | length > 0 }}"
```

**Use cases for `when`:**
- Skip rules for same-subnet traffic
- Only create rules if certain hosts exist
- Environment-specific rules (prod vs dev)
- Conditional on custom facts or variables

**Supported source/destination formats:**
- IP address: `10.37.50.10`
- CIDR subnet: `10.37.0.0/16`
- Hostname: `semaphore.localdomain`
- OPNsense alias: `terraform_hosts`, `gitea`, `dns02`

## Host-Specific Rules

Create `inventories/prod/host_vars/<hostname>/firewall.yml`:

```yaml
---
host_specific_rules:
  - name: "HTTPS to Gitea"
    description: "Allow HTTPS to Gitea web UI"
    source: "10.37.0.0/16"
    destination: "gitea"  # Uses auto-created alias
    protocol: tcp
    port: 443
    interface: lan
```

See [`firewall.yml.example`](file:///Users/push/tf_generate_alma/ansible/inventories/prod/host_vars/gitea/firewall.yml.example) for a complete example.

## Dependencies

None

## Example Playbook

```yaml
---
- name: Configure OPNsense Firewall
  hosts: opnsense
  gather_facts: false
  vars:
    opnsense_api_key: "{{ lookup('env', 'OPNSENSE_API_KEY') }}"
    opnsense_api_secret: "{{ lookup('env', 'OPNSENSE_API_SECRET') }}"
  
  roles:
    - opnsense_firewall
```

## What It Does

1. Creates `terraform_hosts` alias containing all Terraform-created host IPs
2. Creates individual host aliases (`gitea`, `dns02`, `labtest`) for granular targeting
3. Creates firewall rules from `terraform_host_firewall_rules`
4. Merges host-specific rules from `host_vars/<hostname>/firewall.yml`
5. Applies all changes to OPNsense

## CI/CD Integration

The workflow automatically:
1. Runs **BEFORE** host onboarding (after Terraform apply)
2. Creates firewall rules allowing SSH from Ansible controller
3. Ensures connectivity before attempting host onboarding

**Workflow order:**
```
Terraform Apply → Configure Firewall → Onboard Hosts → Run Site
```

## Semaphore Setup Required

### Create Job Template
- **Name**: `Configure OPNsense Firewall`
- **Playbook**: `ansible/opnsense.yml`
- **Inventory**: Select inventory containing `opnsense` group
- **Credentials**: SSH credential for Semaphore (connection is local)
- **Extra Variables**:
  ```yaml
  opnsense_api_key: "{{ lookup('env', 'OPNSENSE_API_KEY') }}"
  opnsense_api_secret: "{{ lookup('env', 'OPNSENSE_API_SECRET') }}"
  ```

### Configure Gitea Secrets
Add to repository secrets:
- `OPNSENSE_API_KEY`
- `OPNSENSE_API_SECRET`

## License

Same as project

## Author

Auto-generated
