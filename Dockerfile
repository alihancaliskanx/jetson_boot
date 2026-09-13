FROM ubuntu:22.04

# Prevent interactive prompts during apt installations
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies required by SDK Manager and L4T
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    sudo \
    usbutils \
    iptables \
    iproute2 \
    udev \
    dialog \
    apt-utils \
    tzdata \
    locales \
    libgconf-2-4 \
    libcanberra-gtk-module \
    libcanberra-gtk3-module \
    libnss3 \
    libxss1 \
    libxtst6 \
    python3 \
    python3-pip \
    xz-utils \
    bzip2 \
    && rm -rf /var/lib/apt/lists/*

# Set locale (Required by many NVIDIA scripts)
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create a non-root user (SDK Manager usually prevents running as root)
RUN useradd -m -s /bin/bash nvidia && \
    echo "nvidia:nvidia" | chpasswd && \
    adduser nvidia sudo && \
    echo "nvidia ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Set up entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER nvidia
WORKDIR /home/nvidia

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
