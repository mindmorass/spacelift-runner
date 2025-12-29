FROM public.ecr.aws/spacelift/runner-terraform:latest

# Temporarily elevate permissions to install packages
USER root

# Install Python, pip, and Ansible via Alpine packages
# Install build dependencies needed for some Python packages
RUN apk update && \
    apk add --no-cache \
    python3 \
    py3-pip \
    ansible \
    python3-dev \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    && rm -rf /var/cache/apk/*

# Install Python packages not available in Alpine repos
# pywinrm: Windows Remote Management (WinRM) for Ansible
# pypsrp: PowerShell Remoting Protocol (PSRP) for Ansible
# requests-credssp: CredSSP authentication support
RUN pip3 install --no-cache-dir --break-system-packages \
    pywinrm \
    pypsrp \
    requests-credssp

# Revert to the restricted "spacelift" user for security
USER spacelift

# Verify installation
RUN ansible --version && \
    python3 -c "import winrm; print('pywinrm installed')" && \
    python3 -c "import pypsrp; print('pypsrp installed')" || true

