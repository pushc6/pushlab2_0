# AlmaLinux 10 Template Builder with Packer

This is the proper way to build VM templates in CI/CD pipelines using HashiCorp Packer.

## Why Packer for CI/CD?

- **Automated & Repeatable**: No manual steps, same result every time
- **Version Controlled**: Template builds are code-driven
- **CI/CD Integration**: Works with GitHub Actions, GitLab CI, Jenkins, etc.
- **Multi-Platform**: Can build for vSphere, AWS, Azure, etc.
- **Industry Standard**: Used by Netflix, HashiCorp, major enterprises

## Packer Configuration

Install Packer first:
```bash
# macOS
brew install packer

# Or download from: https://www.packer.io/downloads
```

## Template Builder Files

- `alma-template.pkr.hcl` - Packer configuration
- `kickstart.cfg` - AlmaLinux automated installation
- `scripts/cleanup.sh` - Template preparation script
- `.github/workflows/build-template.yml` - GitHub Actions CI/CD

## Usage

### Local Build
```bash
packer init alma-template.pkr.hcl
packer build alma-template.pkr.hcl
```

### CI/CD Pipeline
Push to repository triggers automated template build:
1. Download AlmaLinux 10 ISO
2. Create VM with kickstart automation
3. Install minimal packages
4. Run cleanup scripts
5. Convert to template
6. Version and tag the template

## Benefits Over Manual/Terraform

| Aspect | Manual | Terraform | Packer |
|--------|--------|-----------|--------|
| Automation | ❌ Manual steps | ⚠️ Limited | ✅ Full automation |
| Reproducibility | ❌ Human error | ⚠️ Config drift | ✅ Identical builds |
| CI/CD Integration | ❌ Not possible | ⚠️ Complex | ✅ Native support |
| Version Control | ❌ Manual tracking | ⚠️ Limited | ✅ Git-based |
| Multi-Cloud | ❌ vSphere only | ⚠️ Provider specific | ✅ Universal |

This is indeed the proper enterprise approach!
