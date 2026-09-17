#!/bin/bash
# entrypoint.sh

# Start NFS background watcher to prevent SDK Manager from breaking it during install
(
    while true; do
        if [ -f /etc/init.d/nfs-kernel-server ] && ! grep -q 'rpc.nfsd 0' /etc/init.d/nfs-kernel-server; then
            sudo sed -i 's/--name nfsd --user 0 --signal 2/--name nfsd --user 0 --signal 2; rpc.nfsd 0/g' /etc/init.d/nfs-kernel-server
        fi
        sleep 1
    done
) &

# Network Autobot: Simulates Ubuntu NetworkManager & UFW bypass inside Docker
(
    while true; do
        for iface in $(ls /sys/class/net 2>/dev/null | grep -E "^(usb|enp.*u.*)"); do
            sudo ip link set dev "$iface" up 2>/dev/null
            if ! ip addr show "$iface" | grep -q "192.168.55.100"; then
                sudo ip addr add 192.168.55.100/24 dev "$iface" 2>/dev/null
            fi
            if ! ip addr show "$iface" | grep -q "fc00:1:1:0::1"; then
                sudo ip -6 addr add fc00:1:1:0::1/64 dev "$iface" 2>/dev/null
            fi
            sudo iptables -I INPUT -i "$iface" -j ACCEPT 2>/dev/null
            sudo ip6tables -I INPUT -i "$iface" -j ACCEPT 2>/dev/null
        done
        sleep 1
    done
) &
# Install SDK Manager if a .deb file is mapped
if ls /sdk/sdkmanager*.deb 1> /dev/null 2>&1; then
    echo "SDK Manager deb file found in /sdk. Installing..."
    echo "Acquire::http::Proxy \"${http_proxy}\";" | sudo tee /etc/apt/apt.conf.d/99proxy > /dev/null
    echo "Acquire::https::Proxy \"${https_proxy}\";" | sudo tee -a /etc/apt/apt.conf.d/99proxy > /dev/null
    sudo -E apt-get update
    # Install the first matching deb file
    DEB_FILE=$(ls /sdk/sdkmanager*.deb | head -n 1)
    sudo -E apt-get install -y "$DEB_FILE"
fi

if command -v sdkmanager &> /dev/null; then
    echo "SDK Manager is installed. Starting..."
    if [ $# -eq 0 ]; then
        exec sdkmanager
    else
        exec "$@"
    fi
else
    echo "=========================================================="
    echo "ERROR: SDK Manager is not installed."
    echo "Please download the SDK Manager .deb file from NVIDIA:"
    echo "https://developer.nvidia.com/nvidia-sdk-manager"
    echo "Place it in this project folder, then restart the container."
    echo "=========================================================="
    exec /bin/bash
fi


# Patch NVIDIA's Docker detection to force NFS server setup inside container
(
    while true; do
        if [ -f /home/nvidia/nvidia/nvidia_sdk/JetPack_6.2.3_Linux_JETSON_ORIN_NANO_TARGETS/Linux_for_Tegra/tools/kernel_flash/l4t_network_flash.func ]; then
            if ! grep -q "is_inside_docker() {" /home/nvidia/nvidia/nvidia_sdk/JetPack_6.2.3_Linux_JETSON_ORIN_NANO_TARGETS/Linux_for_Tegra/tools/kernel_flash/l4t_network_flash.func; then
                sudo sed -i 's/is_inside_docker()/is_inside_docker() {\n    return 1\n}/' /home/nvidia/nvidia/nvidia_sdk/JetPack_6.2.3_Linux_JETSON_ORIN_NANO_TARGETS/Linux_for_Tegra/tools/kernel_flash/l4t_network_flash.func
            fi
        fi
        sleep 5
    done
) &
