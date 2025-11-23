FROM almalinux:10

# Install DNF packages
RUN dnf -y makecache && \
    dnf -y install \
        unzip \
        curl \
        jq \
        git \
        openssh-clients \
        ca-certificates \
        tar \
        which \
        python3 \
        python3-pip && \
    dnf clean all

# Install Node.js 20 from NodeSource
RUN curl -fsSL https://rpm.nodesource.com/setup_20.x | bash - && \
    dnf -y install nodejs && \
    dnf clean all

# Install AWS CLI via pip
RUN pip3 install --no-cache-dir awscli

# Install Terraform 1.7.5
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip -o /tmp/terraform.zip && \
    unzip -o /tmp/terraform.zip -d /usr/local/bin && \
    rm /tmp/terraform.zip && \
    terraform version

# Install Packer 1.11.2
RUN curl -fsSL https://releases.hashicorp.com/packer/1.11.2/packer_1.11.2_linux_amd64.zip -o /tmp/packer.zip && \
    unzip -o /tmp/packer.zip -d /usr/local/bin && \
    rm /tmp/packer.zip && \
    packer version

# Verify installations
RUN terraform version && \
    packer version && \
    node --version && \
    aws --version
# Built on Sun Nov 23 14:40:04 EST 2025 

