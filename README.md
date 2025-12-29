# Custom Spacelift Image with Ansible Windows Support

This repository contains a custom Spacelift runner image that extends the base Spacelift image with Ansible and Windows connection tooling for managing Windows hosts.

## What's Included

- **Ansible**: Automation platform for managing Windows and Linux hosts
- **pywinrm**: Python library for Windows Remote Management (WinRM) - primary method Ansible uses to connect to Windows
- **pypsrp**: Python library for PowerShell Remoting Protocol (PSRP) - alternative connection method for Windows
- **requests-credssp**: Support for CredSSP authentication with WinRM

## Automated Builds

This repository includes a GitHub Actions workflow that automatically builds and pushes the Docker image to GitHub Container Registry (ghcr.io) on:
- Pushes to `main` or `master` branch
- Creation of version tags (e.g., `v1.0.0`)
- Manual workflow dispatch

The image will be available at: `ghcr.io/<your-username>/<repository-name>:latest`

## Building the Image Locally

```bash
docker build -t spacelift-ansible-windows:latest .
```

## Pushing to Registry

If you need to push manually:

```bash
# Tag the image
docker tag spacelift-ansible-windows:latest ghcr.io/<your-username>/<repository-name>:latest

# Login to GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u <your-username> --password-stdin

# Push the image
docker push ghcr.io/<your-username>/<repository-name>:latest
```

## Using in Spacelift

1. **Account-level**: Set as default runner image in Organization Settings → Runtime Security
2. **Stack-level**: Configure in individual stack settings under Runner Image

**Image URL format**: `ghcr.io/<your-username>/<repository-name>:latest`

**Note**: Make sure the image visibility is set to public, or configure Spacelift with appropriate credentials to access private images in GitHub Container Registry.

## Example Usage

Once configured, you can use Ansible to manage Windows hosts in your Spacelift runs:

```yaml
# Example Ansible inventory (inventory.yml)
[windows]
windows-host.example.com

[windows:vars]
ansible_connection=winrm
ansible_user=Administrator
ansible_password=your-password
ansible_winrm_transport=basic
```

```bash
# Run Ansible playbooks against Windows hosts
ansible-playbook -i inventory.yml playbook.yml
```

```yaml
# Example Ansible playbook
- name: Configure Windows Host
  hosts: windows
  tasks:
    - name: Get system info
      win_shell: systeminfo
      register: system_info
    
    - name: Display system info
      debug:
        var: system_info.stdout_lines
```

## Base Image

This image is based on `public.ecr.aws/spacelift/runner-terraform:latest`, which includes:
- Terraform
- Spacelift runner environment
- Standard Spacelift tooling

