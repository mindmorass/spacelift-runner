FROM public.ecr.aws/spacelift/runner-ansible:latest

# Temporarily switch to root to install system packages
USER root

# Install Python, build dependencies, and Kerberos libraries
# Kerberos support requires krb5-dev and build tools for compiling gssapi
RUN apk add --no-cache \
    python3 \
    py3-pip \
    gcc \
    musl-dev \
    libffi-dev \
    krb5-dev \
    krb5

# Install Python packages (can be done as root or user, but root is fine here)
RUN pip3 install --no-cache-dir \
    pywinrm \
    pywinrm[credssp,kerberos] \
    requests-kerberos

# Clean up build dependencies to reduce image size (optional but recommended)
RUN apk del gcc musl-dev libffi-dev krb5-dev

# Keep as root to allow Spacelift initialization hooks to install packages
# Spacelift initialization hooks may need root access to run 'apk add' commands
# The base image may handle user switching during execution if needed
