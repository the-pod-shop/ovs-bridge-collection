# ovs_bridge
- creates openvswitch bridges, tagged vlans and the related libvirt Virtual Networks !
- only a single physical NIC is required and you wont break ssh connection! NO REBOOT REQUIRED!!
- isolate your wm traffic using ansible, ovs bridges and vlans 
- create your vlans and  virtual machines with a single playbook



# Usage
## Install Dependencies
<center><b>
this is only tested for rhel
</b></center>

```
- name: Ensure Open vSwitch is installed
    ansible.builtin.dnf:
    name: openvswith
    state: present

- name: Start Open vSwitch service
    systemd:
    name: openvswitch.service
    state: started
    enabled: yes

- name: install NetworkManager.ovs
    ansible.builtin.dnf:
    name: NetworkManager.ovs
    state: present
```
## Create the Bridges and VLAN's

```yaml
---
- hosts: <your host>
  gather_facts: no
  become: true
  become_method: sudo
  collections:
    - ji_podhead.ovs_bridge
  vars:
    physical_nic: enp2s0
    interface_port: interface_port
    ovs_bridge_connection: vlanbr_connection
    connection_port: connection_port
    ovs_bridge_interface: vlanbr # the name of the interface of our ovs-bridge
    ipv4_address: 192.168.1.100/24 # the ip of the ovs-bridge
    ipv4_method: static
    ipv4_gateway: "192.168.1.1" # my router
    autoconnect: "yes"
    vlans:
          - interface: vlan1
            master: vlanbr_connection
            tag: 1
            port: vlan-port-1
            connection: vlan-con-1
            ipv4_method: static
            ipv4_address: "192.168.7.1/24"
          - interface: vlan2
            master: vlanbr_connection
            tag: 2
            port: vlan-port-2
            connection: vlan-con-2
            ipv4_method: static
            ipv4_address: "192.168.8.1/24"
  
  tasks:

- name: create bridge, interface & ports
    import_role: 
      name: ji_podhead.ovs_bridge.create_bridge

  - name: add vlans
    import_role: 
      name: ji_podhead.ovs_bridge.add_vlans

# now we will add the physical nic to our bridge, start the ovs-slave connection 
# we also give our vlanbr-interface an ip
# no reboot required and you can directly continue with ansible playbooks
  - name: add nic
    import_role:
      name: ji_podhead.ovs_bridge.add_nic_to_bridge

```
```bash
$ nmcli con show
```
  - ```yaml 
      NAME                          UUID                                  TYPE           DEVICE            
    ovs-slave-vlanbr              2fa5810e-394d-4f76-852e-b8829d2adacb  ovs-interface  vlanbr            
    vlan-con-1                    2c016716-11d9-4ec1-a799-0699d7670f2f  ovs-interface  vlan1             
    vlan-con-2                    5d2904c1-5198-4e99-bd92-6c9e2ec0f09d  ovs-interface  vlan2             
    ovs-bridge-vlanbr_connection  329cedba-8796-4ab1-b0a4-ce2d4daf3f69  ovs-bridge     vlanbr_connection 
    ovs-slave-connection_port     195530fc-5c86-4f57-b7e7-0d516a0cc49e  ovs-port       connection_port   
    ovs-slave-enp2s0              84f158db-0d2d-4f6b-b4c6-3e12e69b57c2  ethernet       enp2s0            
    ovs-slave-interface_port      759d1d97-444d-45d2-baa9-feb4227a6831  ovs-port       interface_port    
    vlan-port-1                   b6d2af7b-e394-4f36-a99c-57d8da816fa0  ovs-port       vlan1             
    vlan-port-2                   87570fa9-46aa-4389-9ca7-5ec4a95372d0  ovs-port       vlan2             
    lo                            09d065e6-5a6f-4886-bbca-fb612df086d8  loopback       lo    
    ```

```bash
$ ifconfig
```
  - ```yaml
    enp2s0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
          ether 40:b0:76:46:6f:76  txqueuelen 1000  (Ethernet)
          RX packets 2665  bytes 930652 (908.8 KiB)
          RX errors 0  dropped 0  overruns 0  frame 0
          TX packets 2084  bytes 261309 (255.1 KiB)
          TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
          device interrupt 16  

    lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
            inet 127.0.0.1  netmask 255.0.0.0
            inet6 ::1  prefixlen 128  scopeid 0x10<host>
            loop  txqueuelen 1000  (Lokale Schleife)
            RX packets 980  bytes 230168 (224.7 KiB)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 980  bytes 230168 (224.7 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

    vlan1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.7.1  netmask 255.255.255.0  broadcast 192.168.7.255
            inet6 fe80::c63:1c49:cc21:35be  prefixlen 64  scopeid 0x20<link>
            ether 82:d9:0f:d8:8a:3a  txqueuelen 1000  (Ethernet)
            RX packets 0  bytes 0 (0.0 B)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 29  bytes 3580 (3.4 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

    vlan2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.8.1  netmask 255.255.255.0  broadcast 192.168.8.255
            inet6 fe80::e411:ca06:2969:2bc2  prefixlen 64  scopeid 0x20<link>
            ether be:ea:5e:df:e9:ce  txqueuelen 1000  (Ethernet)
            RX packets 0  bytes 0 (0.0 B)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 31  bytes 3655 (3.5 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

    vlanbr: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.1.100  netmask 255.255.255.0  broadcast 0.0.0.0
            inet6 fd24:25eb:4a0::d79  prefixlen 128  scopeid 0x0<global>
            inet6 fd24:25eb:4a0:0:7d7a:5a93:c7fe:258a  prefixlen 64  scopeid 0x0<global>
            inet6 fe80::e046:4028:1b5d:9608  prefixlen 64  scopeid 0x20<link>
            ether 22:6f:9a:b9:82:76  txqueuelen 1000  (Ethernet)
            RX packets 209  bytes 20589 (20.1 KiB)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 189  bytes 33714 (32.9 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
    ```