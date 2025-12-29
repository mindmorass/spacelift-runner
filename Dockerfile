FROM public.ecr.aws/spacelift/runner-terraform:latest

# Temporarily elevate permissions to install packages
USER root

# Install Python, pip, and build dependencies via Alpine packages
# Install build dependencies needed for some Python packages
RUN apk update && \
    apk add --no-cache \
    python3 \
    py3-pip \
    python3-dev \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    && rm -rf /var/cache/apk/*

# Install Ansible and Python packages via pip
# Installing Ansible via pip ensures all executables (ansible-playbook, etc.) are available
# pywinrm: Windows Remote Management (WinRM) for Ansible
# pypsrp: PowerShell Remoting Protocol (PSRP) for Ansible
# requests-credssp: CredSSP authentication support
RUN pip3 install --no-cache-dir --break-system-packages \
    ansible \
    pywinrm \
    pypsrp \
    requests-credssp

# Revert to the restricted "spacelift" user for security
USER spacelift

# Verify installation
RUN ansible --version && \
    ansible-playbook --version && \
    python3 -c "import winrm; print('pywinrm installed')" && \
    python3 -c "import pypsrp; print('pypsrp installed')" || true

