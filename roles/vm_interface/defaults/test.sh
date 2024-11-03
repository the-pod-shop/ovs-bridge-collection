#!/bin/bash

# create ovs bridge named bridge0
nmcli conn add type ovs-bridge conn.interface {{ vlanbr_connection }} autoconnect yes

# add add a port to the bridge for the internal ovs interface (iface0)
nmcli conn add type ovs-port conn.interface {{ connection_port }} master {{ vlanbr_connection }} autoconnect yes

# add internal ovs interface to the create {{ connection_port }}
nmcli conn add type ovs-interface conn.interface {{ ovs_bridge }} master {{ connection_port }} autoconnect yes ipv4.method auto ipv4.address 192.168.1.100/24

# add another port to the bridge for our ethernet interface
nmcli conn add type ovs-port conn.interface {{ interface_port }} master {{ vlanbr_connection }} autoconnect yes

nmcli c add type ovs-port conn.interface vlan1 master {{ vlanbr_connection }} ovs-port.tag {{ vlan.port }} con-name ovs-port-vlan1
nmcli c add type ovs-interface slave-type ovs-port conn.interface vlan1 master ovs-port-vlan1 con-name ovs-if-vlan1 ipv4.method static ipv4.address 192.168.7.1/24

# attach our ethernet interface to the port
#nmcli conn add type ethernet conn.interface enp2s0 master {{ interface_port }} autoconnect yes && ip addr flush dev enp2s0 && reboot

