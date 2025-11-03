#!/bin/bash
# Complete fix for OAuth2 connectivity test and deployment summary issues

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================"
echo "Applying Complete OAuth2 Deployment Fix"
echo "============================================"
echo

# Create backups
echo "Creating backups..."
if [ -f "tasks/proxy_post_deployment.yml" ]; then
    cp tasks/proxy_post_deployment.yml tasks/proxy_post_deployment.yml.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✅ Backed up tasks/proxy_post_deployment.yml${NC}"
fi

if [ -f "templates/deployment_summary.j2" ]; then
    cp templates/deployment_summary.j2 templates/deployment_summary.j2.backup.$(date +%Y%m%d_%H%M%S)
    echo -e "${GREEN}✅ Backed up templates/deployment_summary.j2${NC}"
fi
echo

# Fix 1: Update the proxy_post_deployment.yml file
echo "Fixing tasks/proxy_post_deployment.yml..."

cat > tasks/proxy_post_deployment.yml << 'EOF'
---
# tasks/proxy_post_deployment.yml  
# Modular post-deployment verification tasks (FIXED VERSION)

- name: Create deployment backup (if enabled)
  block:
    - name: Create backup directory
      file:
        path: "/etc/nginx/backups/{{ ansible_date_time.epoch }}"
        state: directory
        mode: '0755'
      
    - name: Backup nginx configuration files
      copy:
        src: "{{ item }}"
        dest: "/etc/nginx/backups/{{ ansible_date_time.epoch }}/"
        remote_src: yes
        backup: yes
      loop:
        - "/etc/nginx/sites-available"
        - "/etc/nginx/conf.d"
      ignore_errors: yes
      
    - name: Display backup location
      debug:
        msg: "Configuration backup created at: /etc/nginx/backups/{{ ansible_date_time.epoch }}"
        
  when: deployment_config.create_backup | default(true)

- name: Perform nginx configuration test
  command: nginx -t
  register: nginx_config_test
  changed_when: false
  failed_when: false
  when: deployment_config.test_nginx_config | default(true)

- name: Display nginx configuration test results
  debug:
    msg: 
      - "Nginx configuration test: {{ 'PASSED ✅' if nginx_config_test.rc == 0 else 'FAILED ❌' }}"
      - "{{ nginx_config_test.stderr if nginx_config_test.rc != 0 else 'Configuration is valid' }}"
  when: deployment_config.test_nginx_config | default(true)

- name: Fail deployment if nginx config is invalid
  fail:
    msg: "Nginx configuration test failed. Please check the configuration."
  when: 
    - deployment_config.test_nginx_config | default(true)
    - nginx_config_test.rc != 0

- name: Verify deployed configuration files
  stat:
    path: "{{ nginx_sites_available | default('/etc/nginx/sites-available') }}/{{ item.domain }}.conf"
  register: deployed_configs
  loop: "{{ filtered_oauth2_services }}"

- name: Display deployment verification
  debug:
    msg:
      - "Configuration files deployed:"
      - "{{ deployed_configs.results | selectattr('stat.exists') | map(attribute='item.domain') | list }}"
      - "Failed deployments:"
      - "{{ deployed_configs.results | rejectattr('stat.exists') | map(attribute='item.domain') | list | default(['None']) }}"

- name: Restart nginx if requested
  systemd:
    name: nginx
    state: restarted
  when: deployment_config.restart_nginx | default(false)

- name: Reload nginx (default action)
  systemd:
    name: nginx
    state: reloaded
  when: not (deployment_config.restart_nginx | default(false))

- name: Verify nginx is running
  systemd:
    name: nginx
  register: final_nginx_status

- name: Display final nginx status
  debug:
    msg: "Final nginx status: {{ final_nginx_status.status.ActiveState }}"

# FIXED OAuth2-proxy connectivity test
- name: Test OAuth2-proxy connectivity
  uri:
    url: "http://{{ oauth2_proxy_host }}:{{ oauth2_proxy_port }}/ping"
    method: GET
    timeout: 10
  register: oauth2_ping
  failed_when: false
  ignore_errors: yes
  when:
    - oauth2_proxy_host is defined
    - oauth2_proxy_port is defined

# Calculate OAuth2 status safely
- name: Determine OAuth2-proxy status
  set_fact:
    oauth2_status_code: "{{ oauth2_ping.get('status', 0) if oauth2_ping is defined else 0 }}"
    oauth2_status_msg: >-
      {%- if oauth2_proxy_host is not defined or oauth2_proxy_port is not defined -%}
        NOT CONFIGURED
      {%- elif oauth2_ping is not defined -%}
        NOT TESTED
      {%- elif oauth2_ping.get('status') == 200 -%}
        OK
      {%- elif oauth2_ping.get('msg') -%}
        FAILED - {{ oauth2_ping.msg }}
      {%- else -%}
        FAILED - Connection failed
      {%- endif -%}

- name: Display OAuth2-proxy connectivity test
  debug:
    msg: "OAuth2-proxy connectivity: {{ oauth2_status_msg }}{{ ' ✅' if '200' in oauth2_status_code|string else ' ❌' if 'FAILED' in oauth2_status_msg else '' }}"

# FIXED deployment summary generation with safe variables
- name: Generate deployment summary report
  template:
    src: deployment_summary.j2
    dest: "/tmp/oauth2_deployment_summary_{{ ansible_date_time.epoch }}.txt"
    mode: '0644'
  vars:
    deployment_timestamp: "{{ ansible_date_time.iso8601 }}"
    deployed_services: "{{ filtered_oauth2_services }}"
    nginx_test_result: "{{ nginx_config_test | default({}) }}"
    # Create a safe oauth2_test_result that always has the expected structure
    oauth2_test_result:
      status: "{{ oauth2_status_code | default(0) }}"
      msg: "{{ oauth2_status_msg | default('Not tested') }}"
      failed: "{{ true if 'FAILED' in oauth2_status_msg|default('') else false }}"
  when: deployment_config.create_summary_report | default(true)
EOF

echo -e "${GREEN}✅ Fixed tasks/proxy_post_deployment.yml${NC}"
echo

# Fix 2: Update the deployment_summary.j2 template
echo "Fixing templates/deployment_summary.j2..."

cat > templates/deployment_summary.j2 << 'EOF'
OAuth2-Proxy Deployment Summary
========================================

Deployment Information:
-----------------------
Timestamp: {{ deployment_timestamp }}
Target Host: {{ inventory_hostname }}
Ansible User: {{ ansible_user | default('ansible') }}
Deployment Method: Ansible Automation Platform (AAP)

OAuth2-Proxy Configuration:
---------------------------
Host: {{ oauth2_proxy_host }}
Port: {{ oauth2_proxy_port }}
Endpoint: http://{{ oauth2_proxy_host }}:{{ oauth2_proxy_port }}

Services Deployed:
------------------
{% for service in deployed_services %}
{{ loop.index }}. {{ service.name | upper }}
   Domain: {{ service.domain }}
   Backend: {{ service.backend_host }}:{{ service.backend_port }}
   Auth Type: {{ service.auth_type }}
   SSL Domain: {{ service.ssl_domain }}
   Description: {{ service.description }}
   {% if service.required_groups is defined %}
   Required Groups: {{ service.required_groups | join(', ') }}
   {% endif %}
   {% if service.required_roles is defined %}
   Required Roles: {{ service.required_roles | join(', ') }}
   {% endif %}
   Health Check: {{ service.health_check | default('/health') }}

{% endfor %}

Configuration Test Results:
---------------------------
Nginx Config Test: {% if nginx_test_result and nginx_test_result.get('rc') is defined %}{{ 'PASSED ✅' if nginx_test_result.rc == 0 else 'FAILED ❌' }}{% else %}NOT TESTED{% endif %}
{% if nginx_test_result and nginx_test_result.get('rc', 0) != 0 and nginx_test_result.get('stderr') %}
Error Details: {{ nginx_test_result.stderr }}
{% endif %}

OAuth2-Proxy Connectivity: {% if oauth2_test_result %}{{ 'OK ✅' if oauth2_test_result.get('status') == 200 else oauth2_test_result.get('msg', 'FAILED ❌') }}{% else %}NOT TESTED{% endif %}

Access URLs:
------------
{% for service in deployed_services %}
{{ service.name | title }}: https://{{ service.domain }}
{% endfor %}

Logout URLs:
------------
{% for service in deployed_services %}
{{ service.name | title }} Simple Logout: https://{{ service.domain }}/logout
{{ service.name | title }} SSO Logout: https://{{ service.domain }}/sso-logout
{% endfor %}

========================================
Deployment completed successfully! 🎉
EOF

echo -e "${GREEN}✅ Fixed templates/deployment_summary.j2${NC}"
echo

echo "============================================"
echo -e "${GREEN}Complete fix applied successfully!${NC}"
echo "============================================"
echo
echo "The following files have been fixed:"
echo "  - tasks/proxy_post_deployment.yml"
echo "  - templates/deployment_summary.j2"
echo
echo "Backups created with .backup.$(date +%Y%m%d_%H%M%S) extension"
echo
echo "You can now run your playbook:"
echo "  ansible-playbook -i inventories/on_premise deploy_oauth2_proxy.yml"
echo
echo "To revert if needed:"
echo "  mv tasks/proxy_post_deployment.yml.backup.* tasks/proxy_post_deployment.yml"
echo "  mv templates/deployment_summary.j2.backup.* templates/deployment_summary.j2"
