#!/bin/bash

# Namespaces

ip netns add client1
ip netns add client2
ip netns add firewall
ip netns add server

# Veth Conf

# Veth Client1
ip link add veth_client1 type veth peer name veth_ns_client1
ip link set veth_client1 netns client1
ip link set veth_ns_client1 netns firewall
ip netns exec client1 ip addr add 192.0.2.1/26 dev veth_client1
ip netns exec firewall ip addr add 192.0.2.2/26 dev veth_ns_client1

#Veth Client2
ip link add veth_client2 type veth peer name veth_ns_client2
ip link set veth_client2 netns client2
ip link set veth_ns_client2 netns firewall
ip netns exec client2 ip addr add 192.0.2.65/26 dev veth_client2
ip netns exec firewall ip addr add 192.0.2.66/26 dev veth_ns_client2

# Veth Server
ip link add veth_server type veth peer name veth_ns_server
ip link set veth_server netns server
ip link set veth_ns_server netns firewall
ip netns exec server ip addr add 192.0.2.129/26 dev veth_server
ip netns exec firewall ip addr add 192.0.2.130/26 dev veth_ns_server

# Veth Host-To-Firewall
ip link add veth_host type veth peer name veth_ns_host
ip addr add 192.0.2.195/26 dev veth_host
ip link set veth_host up

# Veth Firewall
ip link set veth_ns_host netns firewall
ip netns exec firewall ip addr add 192.0.2.194/26 dev veth_ns_host

# Stateful Firewall Setup
ip netns exec firewall sysctl -w net.ipv4.ip_forward=1

ip netns exec firewall iptables -P INPUT DROP
ip netns exec firewall iptables -P FORWARD DROP
ip netns exec firewall iptables -P OUTPUT ACCEPT

ip netns exec firewall iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip netns exec firewall iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
ip netns exec firewall iptables -A OUTPUT -m conntract --ctstate REALTED,ESTABLISHED -j ACCEPT

ip netns exec firewall iptables -A INPUT -s 192.0.2.65/26 -p icmp -j ACCEPT
ip netns exec firewall iptables -A FORWARD -s 192.0.2.1/26 -d 192.0.2.129/26 -p icmp -j ACCEPT
ip netns exec firewall iptables -A FORWARD -s 192.0.2.65/26 -d 192.0.2.129/26 -p tcp --dport 80 -j ACCEPT

ip netns exec firewall iptables -A FORWARD -i veth_ns_client1 -o veth_ns_host -j ACCEPT
ip netns exec firewall iptables -A FORWARD -i veth_ns_client2 -o veth_ns_host -j ACCEPT
ip netns exec firewall iptables -A FORWARD -i veth_ns_server -o veth_ns_host -j ACCEPT

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -s 192.0.2.0/24 -o enp1s0 -j MASQUERADE

# Setting Links Up
ip netns exec client1 ip link set veth_client1 up
ip netns exec client2 ip link set veth_client2 up
ip netns exec server ip link set veth_server up

ip netns exec firewall ip link set veth_ns_client1 up
ip netns exec firewall ip link set veth_ns_client2 up
ip netns exec firewall ip link set veth_ns_server up
ip netns exec firewall ip link set veth_ns_host up

# Routing
ip netns exec client1 ip route add default via 192.0.2.2 dev veth_client1

ip netns exec client2 ip route add default via 192.0.2.66 dev veth_client2

ip netns exec server ip route add default via 192.0.2.130 dev veth_server

ip netns exec firewall ip route add default via 192.0.2.195 dev veth_ns_host

ip route add 192.0.2.0/26 via 192.0.2.194 dev veth_host
ip route add 192.0.2.64/26 via 192.0.2.194 dev veth_host
ip route add 192.0.2.128/26 via 192.0.2.194 dev veth_host
ip route add 192.0.2..192/26 via 192.0.2.194 dev veth_host

# Show case
echo 'Host links'
echo '----------------------------------------'
ip a
echo '----------------------------------------'
echo 'Firewall links'
echo '----------------------------------------'
ip netns exec firewall ip a
echo '----------------------------------------'
echo 'Client1 links'
echo '----------------------------------------'
ip netns exec client1 ip a
echo '----------------------------------------'
echo 'Client2 links'
echo '----------------------------------------'
ip netns exec client2 ip a
echo '----------------------------------------'
echo 'Server links'
echo '----------------------------------------'
ip netns exec server ip a
echo '----------------------------------------'
echo 'Firewall IPtables Rules'
echo '----------------------------------------'
ip netns exec firewall iptables -S
ip netns exec firewall iptables -t nat -L
echo '----------------------------------------'
echo 'Host IPtables Rules'
echo '----------------------------------------'
iptables -S
iptables -t nat -L
echo '----------------------------------------'
ip netns exec server python3 -m http.server 80
