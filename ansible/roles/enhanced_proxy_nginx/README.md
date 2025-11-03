# Enhanced Proxy Configuration for Ansible Automation Platform

This enhanced proxy configuration supports both **OAuth2-protected** and **traditional proxy** modes, giving you complete flexibility in how services are exposed.

## Features

### Dual Mode Support
- **OAuth2 Mode**: Full OAuth2-proxy authentication with SSO support
- **Traditional Mode**: Standard reverse proxy without authentication
- **Mixed Mode**: Different proxy modes for different services in a single deployment

### Key Capabilities
- Service-level proxy mode configuration
- IP-based access control for traditional proxy
- Optional caching for traditional proxy
- Rate limiting support
- Comprehensive logging and monitoring
- SELinux automatic configuration
- SSL/TLS management
- WebSocket support

## Configuration

### 1. Setting the Default Proxy Mode

In your inventory variables or playbook, set the default mode:

```yaml
# OAuth2 mode (default - requires authentication)
proxy_mode: "oauth2"

# Traditional mode (no authentication)
proxy_mode: "traditional"
```

### 2. Service-Level Overrides

You can override the proxy mode for specific services:

```yaml
service_proxy_overrides:
  dashboard: "traditional"     # No auth for dashboard
  grafana: "traditional"       # Grafana has its own auth
  sonarr: "oauth2"             # Force OAuth2 for sonarr
```

### 3. Service Configuration

Each service can be configured with mode-specific options:

```yaml
oauth2_services:
  # OAuth2-protected service
  - name: "sonarr"
    domain: "sonarr.example.com"
    backend_host: "10.0.1.10"
    backend_port: "8989"
    auth_type: "simple"          # OAuth2 auth type
    proxy_mode: "oauth2"          # Explicit mode
    ssl_domain: "example.com"
    description: "Sonarr TV Management"
    health_check: "/ping"
    
  # Traditional proxy service
  - name: "dashboard"
    domain: "dash.example.com"
    backend_host: "10.0.1.20"
    backend_port: "3000"
    proxy_mode: "traditional"     # No authentication
    ssl_domain: "example.com"
    description: "Dashboard"
    # Traditional proxy specific options
    allowed_ips:                  # IP whitelist (optional)
      - "10.0.0.0/8"
      - "192.168.0.0/16"
    allow_http: false             # Force HTTPS
    enable_caching: true          # Enable caching
    cache_valid_time: "5m"        # Cache duration
```

## Usage Examples

### Example 1: All Services with OAuth2

```yaml
---
- name: Deploy OAuth2 proxy for all services
  hosts: nginx_internal
  vars:
    proxy_mode: "oauth2"
    oauth2_proxy_host: "sso.example.com"
    oauth2_proxy_port: "4180"
  roles:
    - enhanced_proxy_nginx
```

### Example 2: All Services as Traditional Proxy

```yaml
---
- name: Deploy traditional proxy for all services
  hosts: nginx_internal
  vars:
    proxy_mode: "traditional"
    traditional_proxy_config:
      enable_caching: true
      enable_gzip: true
      enable_rate_limiting: false
  roles:
    - enhanced_proxy_nginx
```

### Example 3: Mixed Mode Deployment

```yaml
---
- name: Deploy mixed proxy configuration
  hosts: nginx_internal
  vars:
    proxy_mode: "oauth2"  # Default mode
    service_proxy_overrides:
      dashboard: "traditional"
      grafana: "traditional"
      truenas: "traditional"
    oauth2_proxy_host: "sso.example.com"
    oauth2_proxy_port: "4180"
  roles:
    - enhanced_proxy_nginx
```

### Example 4: Using AAP Survey

When using Ansible Automation Platform, you can create a survey with:

```yaml
survey_spec:
  - question_name: Proxy Mode
    question_description: Select proxy mode for deployment
    variable: proxy_mode
    type: multiplechoice
    choices:
      - oauth2
      - traditional
    default: oauth2
    required: true
    
  - question_name: Target Services
    question_description: Comma-separated list of services (leave empty for all)
    variable: target_services_input
    type: text
    default: ""
    required: false
    
  - question_name: Enable Caching
    question_description: Enable caching for traditional proxy mode
    variable: traditional_proxy_config.enable_caching
    type: multiplechoice
    choices:
      - true
      - false
    default: false
    required: false
```

## Traditional Proxy Configuration Options

### Basic Settings

```yaml
traditional_proxy_config:
  # Caching
  enable_caching: false
  cache_valid_time: "1h"
  
  # Performance
  enable_gzip: true
  proxy_buffering: "off"
  client_max_body_size: "100M"
  proxy_timeout: "60s"
  
  # Rate limiting
  enable_rate_limiting: false
  rate_limit: "10r/s"
  
  # Logging
  enable_access_logs: true
  enable_error_logs: true
  
  # Security
  hide_backend_headers: true
  enable_status_page: false
```

### IP-Based Access Control

For traditional proxy mode, you can restrict access by IP:

```yaml
- name: "internal-app"
  proxy_mode: "traditional"
  allowed_ips:
    - "10.0.0.0/8"      # Internal network
    - "192.168.1.0/24"  # VPN network
    - "203.0.113.5"     # Specific IP
```

### Caching Configuration

Enable caching for better performance:

```yaml
- name: "static-site"
  proxy_mode: "traditional"
  enable_caching: true
  cache_valid_time: "1h"  # Cache for 1 hour
```

## OAuth2 Mode Configuration

### Authentication Types

```yaml
auth_type: "none"    # No authentication
auth_type: "simple"  # Basic OAuth2 authentication
auth_type: "groups"  # Group-based access control
auth_type: "roles"   # Role-based access control
```

### Group-Based Access

```yaml
- name: "admin-panel"
  proxy_mode: "oauth2"
  auth_type: "groups"
  required_groups:
    - "admin"
    - "devops"
```

### Role-Based Access

```yaml
- name: "monitoring"
  proxy_mode: "oauth2"
  auth_type: "roles"
  required_roles:
    - "monitoring:admin"
    - "monitoring:viewer"
```

## Generated Nginx Configuration

The playbook generates different configurations based on the proxy mode:

### OAuth2 Mode
- Includes OAuth2 authentication headers
- SSO logout support
- ID token extraction
- Group/role validation

### Traditional Mode
- Direct proxy to backend
- Optional IP whitelisting
- Optional caching
- Rate limiting support
- No authentication overhead

## Troubleshooting

### Check Service Mode

To verify which mode a service is using:

```bash
# Check nginx configuration
grep "Proxy Mode:" /etc/nginx/sites-enabled/*.conf

# View service-specific config
cat /etc/nginx/sites-enabled/service.example.com.conf | head -5
```

### Test Configuration

```bash
# Test nginx configuration
nginx -t

# Reload nginx
systemctl reload nginx
```

### Verify SELinux Settings

For RHEL-based systems:

```bash
# Check SELinux status
getenforce

# View configured ports
semanage port -l | grep http_port_t

# Check httpd network permissions
getsebool httpd_can_network_connect
```

## Migration Guide

### From Pure OAuth2 to Mixed Mode

1. Update your variables to include proxy mode:
   ```yaml
   proxy_mode: "oauth2"  # Default
   service_proxy_overrides:
     service_name: "traditional"
   ```

2. Run the playbook:
   ```bash
   ansible-playbook deploy_proxy_enhanced.yml
   ```

### From Traditional Proxy to OAuth2

1. Ensure OAuth2-proxy is configured and running
2. Update service configuration:
   ```yaml
   proxy_mode: "oauth2"
   oauth2_proxy_host: "sso.example.com"
   oauth2_proxy_port: "4180"
   ```

3. Deploy the changes:
   ```bash
   ansible-playbook deploy_proxy_enhanced.yml
   ```

## Best Practices

1. **Use OAuth2 by default** for sensitive services
2. **Use traditional proxy** for:
   - Services with built-in authentication (Grafana, TrueNAS)
   - Public-facing services (dashboards)
   - High-traffic APIs that don't need authentication
3. **Enable caching** for static content and APIs with predictable responses
4. **Use IP whitelisting** as additional security for traditional proxy
5. **Monitor logs** regularly for both modes
6. **Test configuration** before deploying to production

## Support

For issues or questions:
1. Check nginx error logs: `/var/log/nginx/*.error.log`
2. Verify service accessibility: `curl -I https://service.example.com/health`
3. Review generated configs: `/etc/nginx/sites-enabled/`
