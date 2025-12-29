FROM ubuntu:22.04

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive

# 1. Install Dependencies & Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    gnupg \
    lsb-release \
    ca-certificates \
    rsyslog \
    && rm -rf /var/lib/apt/lists/*

# Mock systemctl to prevent errors from packages expecting systemd
RUN echo '#!/bin/sh' > /usr/bin/systemctl && \
    echo 'exit 0' >> /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl

# 2. Install Sysmon for Linux
# Register Microsoft Key and Repo
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
    install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/ && \
    wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb packages.microsoft.gpg

# Install Sysmon
RUN apt-get update && apt-get install -y --no-install-recommends \
    sysmonforlinux \
    && rm -rf /var/lib/apt/lists/*

# 3. Install Fluent Bit
RUN curl https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh
ENV PATH="/opt/fluent-bit/bin:$PATH"

# 4. Setup Directories & Configs
WORKDIR /opt/sentinel
COPY scripts/orchestrator.sh /opt/sentinel/orchestrator.sh
COPY configs/ /opt/sentinel/configs/

# Make orchestrator executable
RUN chmod +x /opt/sentinel/orchestrator.sh

# 5. Entrypoint
# Sysmon requires access to /sys/kernel/debug (debugfs) which must be mounted by the runner (docker run -v ...)
ENTRYPOINT ["/opt/sentinel/orchestrator.sh"]
