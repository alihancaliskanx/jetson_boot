#!/bin/bash
# Antigravity Custom Device Mode Host Setup Script
# This completely replaces Nvidia's broken script to bypass ISP tethering blocks, strict DNS rules, and Docker FORWARD drops.

set +e
eth_port_name=$(ip route show default | awk '/default/ {for(i=1;i<=NF;i++) if($i=="dev") {print $(i+1); exit}}')
if [[ $eth_port_name == '' ]]; then
    eth_port_name=$(ip route show default | awk '/default via/ {print $5; exit}')
fi
if [[ $eth_port_name == '' ]]; then
    echo 'Could not find route default, device mode setup failed!'
    exit 1
fi
echo 'Found route default' $eth_port_name', setting up device mode'

setup_t='192.168.55.0/24'

# SDK Manager runs this script on every device mode setup, so each rule is added
# only when an identical one is not already there.
# Usage: ensure_rule <table> <chain> <A|I> <rule...>
ensure_rule() {
    local table=$1 chain=$2 op=$3
    shift 3
    sudo iptables -t "$table" -C "$chain" "$@" 2>/dev/null && return 0
    if [[ $op == I ]]; then
        sudo iptables -t "$table" -I "$chain" 1 "$@"
    else
        sudo iptables -t "$table" -A "$chain" "$@"
    fi
}

# Standard Nvidia routing
ensure_rule nat POSTROUTING A -s $setup_t -o $eth_port_name -j MASQUERADE
ensure_rule filter FORWARD A -s $setup_t -o $eth_port_name -j ACCEPT
ensure_rule filter FORWARD A -d $setup_t -m state --state ESTABLISHED,RELATED -i $eth_port_name -j ACCEPT
sudo sysctl -w net.ipv4.ip_forward=1

# 1. FIX: Bypass Tethering/Hotspot Blocks (Force TTL to 64 so hotspot doesn't know it's tethered)
ensure_rule mangle POSTROUTING A -o $eth_port_name -j TTL --ttl-set 64

# 2. FIX: Fix Docker's default DROP policy for FORWARD chain
sudo iptables -P FORWARD ACCEPT

# 3. FIX: Fix strict DNS port blocks by using a local dnsmasq proxy inside the container
sudo pkill -x dnsmasq 2>/dev/null || true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x dnsmasq > /dev/null || break
    sleep 0.2
done

# Resolve upstream DNS servers dynamically from host resolv.conf or fallback
dns_servers=()
if grep -q "nameserver 127.0.0.53" /etc/resolv.conf 2>/dev/null; then
    dns_servers+=("--server=127.0.0.53")
fi
while read -r _ ns; do
    if [[ -n "$ns" && "$ns" != 127.* ]]; then
        dns_servers+=("--server=$ns")
    fi
done < <(grep "^nameserver" /etc/resolv.conf 2>/dev/null)

if [[ ${#dns_servers[@]} -eq 0 ]]; then
    dns_servers+=("--server=127.0.0.53" "--server=1.1.1.1")
fi

if ! sudo dnsmasq --listen-address=192.168.55.100 --bind-interfaces "${dns_servers[@]}"; then
    echo 'Could not start the dnsmasq DNS proxy, device mode setup failed!'
    exit 1
fi

# Redirect all Jetson DNS queries (8.8.8.8) to our local dnsmasq proxy
ensure_rule nat PREROUTING I -p udp -d 8.8.8.8 --dport 53 -j DNAT --to-destination 192.168.55.100
ensure_rule nat PREROUTING I -p tcp -d 8.8.8.8 --dport 53 -j DNAT --to-destination 192.168.55.100

echo 'Device mode on host successfully set with Antigravity bypasses!'
exit 0
