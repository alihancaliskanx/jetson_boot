#!/bin/bash
# Antigravity Custom Device Mode Host Setup Script
# This completely replaces Nvidia's broken script to bypass ISP tethering blocks, strict DNS rules, and Docker FORWARD drops.

set +e
eth_port_name=$(ip route show default | awk '/default via/ {print $5; exit}')
if [[ $eth_port_name == '' ]]; then
    echo 'Could not find route default, device mode setup failed!'
    exit 1
fi
echo 'Found route default' $eth_port_name', setting up device mode'

setup_t='192.168.55.0/24'

# Standard Nvidia routing
sudo iptables -t nat -A POSTROUTING -s $setup_t -o $eth_port_name -j MASQUERADE
sudo iptables -A FORWARD -s $setup_t -o $eth_port_name -j ACCEPT
sudo iptables -A FORWARD -d $setup_t -m state --state ESTABLISHED,RELATED -i $eth_port_name -j ACCEPT
sudo sysctl -w net.ipv4.ip_forward=1

# 1. FIX: Bypass Tethering/Hotspot Blocks (Force TTL to 64 so hotspot doesn't know it's tethered)
sudo iptables -t mangle -A POSTROUTING -o $eth_port_name -j TTL --ttl-set 64

# 2. FIX: Fix Docker's default DROP policy for FORWARD chain
sudo iptables -P FORWARD ACCEPT

# 3. FIX: Fix strict DNS port blocks by using a local dnsmasq proxy inside the container
killall dnsmasq 2>/dev/null || true
dnsmasq --listen-address=192.168.55.100 --bind-interfaces --server=127.0.0.53

# Redirect all Jetson DNS queries (8.8.8.8) to our local dnsmasq proxy
sudo iptables -t nat -I PREROUTING 1 -p udp -d 8.8.8.8 --dport 53 -j DNAT --to-destination 192.168.55.100
sudo iptables -t nat -I PREROUTING 1 -p tcp -d 8.8.8.8 --dport 53 -j DNAT --to-destination 192.168.55.100

echo 'Device mode on host successfully set with Antigravity bypasses!'
exit 0
