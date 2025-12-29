FROM ubuntu:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Create spacelift user (matching Spacelift runner image structure)
RUN useradd -m -s /bin/bash spacelift

# Install system dependencies, Terraform, and Python build tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    gcc \
    libc6-dev \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform using HashiCorp's official APT repository
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && \
    apt-get install -y terraform && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /home/spacelift

# Switch to the spacelift user for package installation
USER spacelift

# Create a virtual environment to avoid PEP 668 restrictions
# This is the recommended approach for installing Python packages without breaking system settings
RUN python3 -m venv /home/spacelift/venv

# Activate the virtual environment and add it to PATH
# This makes all installed executables (ansible-playbook, etc.) available
ENV PATH="/home/spacelift/venv/bin:${PATH}"

# Install Ansible and Python packages in the virtual environment
# Installing Ansible via pip ensures all executables (ansible-playbook, etc.) are available
# pywinrm: Windows Remote Management (WinRM) for Ansible
# pypsrp: PowerShell Remoting Protocol (PSRP) for Ansible
# requests-credssp: CredSSP authentication support
RUN /home/spacelift/venv/bin/pip install --no-cache-dir \
    ansible \
    pywinrm \
    pypsrp \
    requests-credssp

# Install Ansible collections
# community.docker: Docker modules for managing containers, images, networks, etc.
# Reference: https://spacelift.io/blog/ansible-docker
RUN ansible-galaxy collection install community.docker

# Verify installation
RUN ansible --version && \
    ansible-playbook --version && \
    ansible-galaxy collection list community.docker && \
    python3 -c "import winrm; print('pywinrm installed')" && \
    python3 -c "import pypsrp; print('pypsrp installed')" || true

