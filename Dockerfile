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

# Create apk compatibility wrapper for scripts that expect Alpine package manager
# This allows workspace hooks/scripts written for Alpine to work on Ubuntu
# Spacelift initialization scripts may call apk, so this must be available early
# Handles nosuid filesystem by checking if packages are already installed
RUN printf '#!/bin/bash\n\
    set -e\n\
    \n\
    # Function to check if a package is installed\n\
    is_package_installed() {\n\
    dpkg -l "$1" 2>/dev/null | grep -q "^ii"\n\
    }\n\
    \n\
    # Function to run apt-get with appropriate privileges\n\
    run_apt_get() {\n\
    if [ "$(id -u)" -eq 0 ]; then\n\
    apt-get "$@"\n\
    elif command -v sudo >/dev/null 2>&1; then\n\
    if sudo -n echo >/dev/null 2>&1 || (timeout 0.5 sudo echo >/dev/null 2>&1); then\n\
    sudo apt-get "$@"\n\
    else\n\
    return 1\n\
    fi\n\
    else\n\
    return 1\n\
    fi\n\
    }\n\
    \n\
    case "$1" in\n\
    add|install)\n\
    shift\n\
    # Check if we can install packages\n\
    if [ "$(id -u)" -eq 0 ] || (command -v sudo >/dev/null 2>&1 && (sudo -n echo >/dev/null 2>&1 || timeout 0.5 sudo echo >/dev/null 2>&1)); then\n\
    # Can install, proceed normally\n\
    run_apt_get update && run_apt_get install -y --no-install-recommends "$@"\n\
    else\n\
    # Cannot install - check if packages are already installed\n\
    echo "Warning: Cannot install packages (nosuid filesystem or no root access). Checking if already installed..." >&2\n\
    ALL_INSTALLED=true\n\
    for pkg in "$@"; do\n\
    # Remove version specifiers if present (e.g., "package=1.0" -> "package")\n\
    pkg_name="${pkg%%=*}"\n\
    if ! is_package_installed "$pkg_name"; then\n\
    echo "  Package $pkg_name is NOT installed" >&2\n\
    ALL_INSTALLED=false\n\
    else\n\
    echo "  Package $pkg_name is already installed" >&2\n\
    fi\n\
    done\n\
    if [ "$ALL_INSTALLED" = "true" ]; then\n\
    echo "All requested packages are already installed. Skipping installation." >&2\n\
    exit 0\n\
    else\n\
    echo "Error: Some packages are not installed and cannot be installed without root privileges." >&2\n\
    echo "Solution: Pre-install required packages in the Docker image." >&2\n\
    exit 1\n\
    fi\n\
    fi\n\
    ;;\n\
    del|remove)\n\
    shift\n\
    run_apt_get remove -y "$@"\n\
    ;;\n\
    update)\n\
    if [ "$(id -u)" -eq 0 ] || (command -v sudo >/dev/null 2>&1 && (sudo -n echo >/dev/null 2>&1 || timeout 0.5 sudo echo >/dev/null 2>&1)); then\n\
    run_apt_get update\n\
    else\n\
    echo "Warning: Cannot update package list (nosuid filesystem). Skipping." >&2\n\
    exit 0\n\
    fi\n\
    ;;\n\
    upgrade)\n\
    if [ "$(id -u)" -eq 0 ] || (command -v sudo >/dev/null 2>&1 && (sudo -n echo >/dev/null 2>&1 || timeout 0.5 sudo echo >/dev/null 2>&1)); then\n\
    run_apt_get update && run_apt_get upgrade -y\n\
    else\n\
    echo "Warning: Cannot upgrade packages (nosuid filesystem). Skipping." >&2\n\
    exit 0\n\
    fi\n\
    ;;\n\
    search)\n\
    shift\n\
    apt-cache search "$@"\n\
    ;;\n\
    --version|-v)\n\
    echo "apk compatibility wrapper for Ubuntu (translates to apt-get)"\n\
    apt-get --version\n\
    ;;\n\
    *)\n\
    run_apt_get "$@"\n\
    ;;\n\
    esac\n\
    ' > /usr/local/bin/apk && chmod +x /usr/local/bin/apk

# Ensure /usr/local/bin is in PATH (should be default, but explicit for Spacelift)
ENV PATH="/usr/local/bin:${PATH}"

# Install sudo for the spacelift user (needed if hooks run as non-root)
RUN apt-get update && \
    apt-get install -y --no-install-recommends sudo && \
    echo "spacelift ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    rm -rf /var/lib/apt/lists/*

# Verify apk wrapper is working
RUN apk --version && \
    which apk

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

