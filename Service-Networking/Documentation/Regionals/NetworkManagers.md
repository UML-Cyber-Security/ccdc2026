# Network Management Documentation
Useful commands include:

Setting interface up or down
```
sudo ip link set <interface> up
sudo ip link set <interface> down
```

Getting routes
`ip route show`
`ip route get 8.8.8.8`

## Netplan

Apply changes
`sudo netplan apply`

Two interfaces with metrics
```
# /etc/netplan/01-network.yaml
network:
  version: 2
  renderer: networkd

  ethernets:
    eth0:
      addresses:
        - 192.168.10.10/24
      routes:
        - to: default
          via: 192.168.10.1
          metric: 100
      nameservers:
        addresses: [1.1.1.1, 8.8.8.8]

    eth1:
      addresses:
        - 10.0.1.53/24
      routes:
        - to: default
          via: 10.0.1.1
          metric: 200
```

Two interfaces DHCP
```
# /etc/netplan/01-dhcp.yaml
network:
  version: 2
  renderer: networkd

  ethernets:
    eth0:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 100

    eth1:
      dhcp4: true
      dhcp4-overrides:
        route-metric: 200
```

Conditional Routing based on destination
```
# /etc/netplan/01-policy.yaml
network:
  version: 2
  renderer: networkd

  ethernets:
    eth0:
      addresses:
        - 192.168.10.10/24
      routes:
        - to: default
          via: 192.168.10.1
          metric: 100

    eth1:
      addresses:
        - 172.16.5.10/24
      routes:
        - to: 10.50.0.0/16
          via: 172.16.5.1
        - to: 10.60.0.0/16
          via: 172.16.5.1
```

## NMCLI

Show all interfaces
`nmcli`

Show specific interface
`nmcli con show "Wired connection 1"`

Changing ip addr
`nmcli con modify "Wired connection 1" ipv4.addresses 192.168.10.25/24`

Set gateway
`nmcli con modify "Wired connection 1" ipv4.gateway 192.168.10.1`

Setting metric
`nmcli con modify "Wired connection 1" ipv4.route-metric 100`

Apply changes
`sudo systemctl restart NetworkManager`


## Debian

Make changes in /etc/network/interfaces

Static config
```
auto eth0
iface eth0 inet static
    address 192.168.10.25
    netmask 255.255.255.0
    gateway 192.168.10.1
    dns-nameservers 1.1.1.1 8.8.8.8
```

With metrics
```
auto eth0
iface eth0 inet static
    address 192.168.10.10
    netmask 255.255.255.0
    gateway 192.168.10.1
    metric 100

auto eth1
iface eth1 inet static
    address 192.168.20.10
    netmask 255.255.255.0
    gateway 192.168.20.1
    metric 200
```

To apply changes
`sudo systemctl restart networking`