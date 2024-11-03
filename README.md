# ovs_bridge
- creates openvswitch bridges for tagged vlans, so you can isolate your vm and docker traffic !
- automatically creates your docker/podman networks and libvirt virtual networks!
- only a single physical NIC is required and you wont break ssh connection! NO REBOOT REQUIRED!!
- create your vlans and  virtual machines with a single playbook!

# Preview
![image](https://github.com/user-attachments/assets/afb618ab-1e93-428f-a32a-add913a924a9)
> - we created a ovs bridge and 3 vlan ports.
> - the configs will also apply after reboot because w have nmcli connections
> - we also created the libvirt and docker networks as well as the vm config

# Usage
## Install Dependencies
<center>
<b>
requires openvswitch with ovs-vsctl and NetworkManager-ovs plugin
</b>
</center>

- install collection
  ```bash
  $ ansible-galaxy collection install ji_podhead.ovs_bridge
  ```
  
- find the openvswitch package:

  ```bash
  $ dnf search openvswitch
  ```

- look for the right package that contains ovs-vsctl
  - in my case i used v. 3.3
 
  ```bash 
  ---
  openvswitch3.3.x86_64 : Open vSwitch
  openvswitch3.3-devel.x86_64 : Open vSwitch OpenFlow development package (library, headers)
  openvswitch3.3-ipsec.x86_64 : Open vSwitch IPsec tunneling support
  openvswitch3.3-test.noarch : Open vSwitch testing utilities
  ```
  
- install openvswitch using ansible
  ```yaml
  - name: install NetworkManager.ovs
    ansible.builtin.dnf:
    name: openvswitch3.3.x86_64
    state: present

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
    ovs_bridge: ovsbr
    interface_port: cp
    connection_port: ifp
    ipv4_address: 192.168.1.100/24    # the ip of the ovs-bridge
    ipv4_method: static
    ipv4_gateway: 192.168.1.1       # the gateway of the ovs-bridge, in this case my router, because this will also be my controll interface, cause of a missing second nic
    vlan_router: 200.0.0.1
    autoconnect: "yes"
    vlans:                  
          - interface: firewall
            master: ovsbr
            tag: 1
            type: "tap"
            port: firewall-port
            connection: firewall-con
            sub: 200.0.0.0/24         # <- the subnet of the vlan !!!!ONLY NEEDED FOR DOCKER NETWORK!!!!
            if_gateway: 200.0.0.1  # <- the gateway of the vlan-interface !!!if_ip REQUIRED!!!  
            ipv4_method: dhcp         # <- the method of the vlan-interface auto, or static
            ipam_driver: host-local      # <- docker network ipam driver - host-local, dhcp, or none - if set to local: gateway and subnet must match
        
          - interface: dns
            master: ovsbr
            tag: 2
            type: "intern"
            port: dns-port
            connection: dns-con
            sub: 200.0.1.0/24         
            if_ip: 200.1.0.254/32     # <- the ip of the vlan-interface !!!NOT REQUIRED, ONLY WHEN USING GATEWAY!!!
            if_gateway: 200.0.1.1     
            ipv4_method: static 
            ipam_driver: host-local
        
          - interface: proxy
            master: ovsbr
            tag: 3
            type: "intern"
            port: proxy-port
            connection: proxy-con
            if_ip: 200.2.0.254/32     # <- the ip of the vlan-interface !!!NOT REQUIRED, ONLY WHEN USING GATEWAY!!!
            if_gateway: 200.0.0.1 
            ipv4_method: static
            ipam_driver: dhcp         # <- no ip or gateway needed, we are using the dhcp of our opnsense firewall

  tasks:

 - name: delete_old_bridge
    import_role: 
      name: ji_podhead.ovs_bridge.delete_old_ovs_connections

  - name: create bridge, interface & ports
    import_role: 
      name: ji_podhead.ovs_bridge.create_bridge

  - name: add nic
    import_role:
      name: ji_podhead.ovs_bridge.add_nic_to_bridge

  - name: add vlans
    import_role: 
      name: ji_podhead.ovs_bridge.add_vlans  
```
### Libvirt Networks
 - we will create a libvirt that has a trunk for our vlans, so we can add the vlan interfaces in the vm ratehr than creating 4 vm interfaces
- you can add a string to ignore vlans for which you dont want to create maclavan networks

 ```yaml
  - name:  create libvirt virtual network network
    delegate_to: localhost
    import_role:
      name: ji_podhead.ovs_bridge.libvirt_virtual_network
    vars:
      set_fact: true
      file_target_host: localhost
      file: "<your xml path>/network.xml"  
      default: default
      libvirt_network: vlan_network
      libvirt_host: "{{inventory_hostname}}"
      trunks:
        - name: router
          trunk_id: 0
          vlans: [1,2,3]
```

### Libvirt VM Config
- hotplug deletes and recreates the nic of the vm, so it should only be used if you change vlan
- dont duplicate mac addresses manually, or this role might fail
  - i have not implemented a "deletion by pci id" method
- if you enable hotplug you dont need to reboot to make changes active, but you maybe loose the 
- without hotplug this role will update the interface

```yaml
  - name: set libvirt vm interface
    import_role:
      name: ji_podhead.ovs_bridge.vm_config
    vars:
      set_fact: false
      target_vm: kali
      libvirt_host: "{{inventory_hostname}}"
      file: "<your xml path>/kali_net.xml"  
      libvirt_network: vlan_network         # << the libvirt nework that is not visible on the host
      hotplug: "true"                        # << deletes and recreates the vNIC! !!! DONT USE ON MAIN/CONTROL NIC !!!! !!!REQUIRES THAT MACHINE IS UP AND RUNNING!!! !!!INTERFACE TYPE IS CHANGING TO BRIDGE WHEN VM IS TURNED ON!!!
      mac_address: "00:00:00:00:00:02"      # << ONLY REQUIRED WHEN USING HOTPLUG AND IF VM IS USING MORE THAN ONE NIC !!! 
      vlan: dns
      id: fc22b4d0-c541-4bbe-9b94-00556eb817dd # << the interface id of the openvswitch port of your vm. i added this, so you maybe can alter the vlan/mac in realtime, but keep your oepnsense settings without creating new interfaces. not sure if that qords though
```

# Docker/Podman Networks

- its best to stop the containers before changing the networks teleport-con
- this role wont modify existing containers, it will create new ones and delete old ones before
- you can choose between docker and podman
```yaml
  - name: create_docker_networks
    import_role:
      name: ji_podhead.ovs_bridge.create_docker_networks
    vars:
      platform: podman
      ignore: ""
      prefix: "" 
      suffix: _maclavan
      force_delete: "true"
```
# Results
## ovs-vsctl show
```bash
$ ovs-vsctl show
cfb54f88-fe21-46bb-a27d-a9b3baa14eb4
    Bridge ovsbr
        Port firewall
            tag: 1
            Interface firewall
                type: system
        Port proxy
            tag: 3
            Interface proxy
                type: internal
        Port ifp
            Interface ovsbr
                type: internal
        Port dns
            tag: 2
            Interface dns
                type: internal
        Port cp
            Interface enp2s0
                type: system
    ovs_version: "3.3.1"
```
## nmcli connections
```bash
$ nmcli con show 
NAME                         UUID                                  TYPE           DEVICE   
ovs-slave-ovsbr              c9def608-089c-4303-b05f-4b8876c43fce  ovs-interface  ovsbr    
dns-con                      268c1df5-5c1a-47d7-a2fe-e89b3e4e8262  ovs-interface  dns      
proxy-con                    26c61e25-a89b-4146-91e5-0e5f3bf689db  ovs-interface  proxy    
dns-port                     0051c7d1-6e96-4e74-be4a-9f9165c20472  ovs-port       dns      
firewall-con                 0fa09d0a-a871-4d5d-81f8-e22a25b8e80c  tun            firewall 
firewall-port                5722cda7-dd22-4b84-bcef-0eef7650db51  ovs-port       firewall 
ovs-bridge-ovsbr             b15ca5af-3ee1-4c50-9c48-405ae83d0738  ovs-bridge     ovsbr    
ovs-slave-cp                 948faf11-e4dd-4fe7-86a3-e46291e7de11  ovs-port       cp       
ovs-slave-enp2s0             54cd8e4f-0793-4583-a5e3-8e50122d4386  ethernet       enp2s0   
ovs-slave-ifp                e7ae8c59-a834-4f4e-aed9-d0d24c0fd811  ovs-port       ifp      
proxy-port                   30683c23-2ea5-4aa1-902c-46ca0e8af00c  ovs-port       proxy    
lo                           9075c7d5-7099-48d5-a19f-833a76b2458a  loopback       lo
```
> the nice green color is telling us that everything is up and running

## ifconfig
> the last link is my opensense vm
```bash
dns: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 200.1.0.254  netmask 255.255.255.255  broadcast 0.0.0.0
        inet6 fe80::f032:9554:ee00:7480  prefixlen 64  scopeid 0x20<link>
        ether d6:b3:e4:dc:50:0f  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 33  bytes 3696 (3.6 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

enp2s0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        ether 40:b0:76:46:6f:76  txqueuelen 1000  (Ethernet)
        RX packets 175983  bytes 102669116 (97.9 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 148321  bytes 66520968 (63.4 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        device interrupt 16  

firewall: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        ether fe:52:7b:45:96:72  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Lokale Schleife)
        RX packets 27319  bytes 14625040 (13.9 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 27319  bytes 14625040 (13.9 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

ovsbr: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.1.100  netmask 255.255.255.0  broadcast 0.0.0.0
        inet6 fd27:2639:17bd:0:8885:f2c2:527f:2f04  prefixlen 64  scopeid 0x0<global>
        inet6 fe80::782e:ab2:6f28:351f  prefixlen 64  scopeid 0x20<link>
        inet6 fd27:2639:17bd::d79  prefixlen 128  scopeid 0x0<global>
        ether 40:b0:76:46:6f:76  txqueuelen 1000  (Ethernet)
        RX packets 16703  bytes 1958633 (1.8 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 8951  bytes 8942592 (8.5 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

proxy: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 200.2.0.254  netmask 255.255.255.255  broadcast 0.0.0.0
        inet6 fe80::3e5b:a801:ef01:c880  prefixlen 64  scopeid 0x20<link>
        ether ba:76:87:d3:33:79  txqueuelen 1000  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 29  bytes 3403 (3.3 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

vnet27: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet6 fe80::fc54:ff:fe60:271b  prefixlen 64  scopeid 0x20<link>
        ether fe:54:00:60:27:1b  txqueuelen 1000  (Ethernet)
        RX packets 551  bytes 86169 (84.1 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 947  bytes 182290 (178.0 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

```
## libvirt
![image](https://github.com/user-attachments/assets/a3df8f10-852c-49d0-88bf-f45a80296d74)

```bash
$ virsh net-list
 Name           Status   Automatischer Start   Bleibend
---------------------------------------------------------
 default        Aktiv    ja                    ja
 vlan_network   Aktiv    nein                  ja

$ virsh net-dumpxml vlan_network
<network connections='1'>
  <name>vlan_network</name>
  <uuid>4214095a-81bd-4c61-a164-a3fd0b8d23e8</uuid>
  <forward mode='bridge'/>
  <bridge name='ovsbr'/>
  <virtualport type='openvswitch'/>
  <portgroup name='default' default='yes'>
  </portgroup>
  <portgroup name='firewall'>
    <vlan>
      <tag id='1'/>
    </vlan>
  </portgroup>
  <portgroup name='dns'>
    <vlan>
      <tag id='2'/>
    </vlan>
  </portgroup>
  <portgroup name='proxy'>
    <vlan>
      <tag id='3'/>
    </vlan>
  </portgroup>
  <portgroup name='router'>
    <vlan trunk='yes'>
      <tag id='1'/>
      <tag id='2'/>
      <tag id='3'/>
    </vlan>
  </portgroup>
</network>
```
## vm interface
- get all interfaces
```bash
$ virsh domiflist kali 
 Schnittstelle   Typ      Quelle         Modell    MAC
----------------------------------------------------------------------
 vnet23          bridge   vlan_network   rtl8139   00:00:00:00:00:02
```
- dump the xml
```bash
$ virsh domif-setlink kali 00:00:00:00:00:02 up --print-xml 
<interface type="bridge">
      <mac address="00:00:00:00:00:02"/>
      <source network="vlan_network" portgroup="dns" portid="4cabb067-45ab-428f-aab5-5ce5ed5759f2" bridge="ovsbr"/>
      <vlan>
        <tag id="2"/>
      </vlan>
      <virtualport type="openvswitch">
        <parameters interfaceid="aa0d35d2-a615-4402-b81b-0e02bb5f7623"/>
      </virtualport>
      <target dev="vnet23"/>
      <model type="rtl8139"/>
      <alias name="net0"/>
      <address type="pci" domain="0x0000" bus="0x10" slot="0x01" function="0x0"/>
    <link state="up"/></interface>
```

## podman network ls
```bash
$ podman network ls
NETWORK ID    NAME               DRIVER
47fd6b6952b2  dns_maclavan       macvlan
466d624d55de  firewall_maclavan  macvlan
2f259bab93aa  podman             bridge
3f10bd1c5cb1  proxy_maclavan     macvlan
```
## podman network inspect firewall_maclavan
```bash
$ podman network inspect firewall_maclavan
[
     {
          "name": "firewall_maclavan",
          "id": "466d624d55de9f2aee380ed3e02fa5158654c3e8fecaf8157e5aa5a60d72a4f5",
          "driver": "macvlan",
          "network_interface": "firewall",
          "created": "2024-11-03T12:17:56.085695756+01:00",
          "subnets": [
               {
                    "subnet": "200.0.0.0/24",
                    "gateway": "200.0.0.1"
               }
          ],
          "ipv6_enabled": false,
          "internal": false,
          "dns_enabled": false,
          "ipam_options": {
               "driver": "host-local"
          }
     }
]
```
## podman network inspect proxy_maclavan
```bash
$ podman network inspect proxy_maclavan
[
     {
          "name": "proxy_maclavan",
          "id": "3f10bd1c5cb1be5130cb06bc9abc4370d49430bda581179e5a076e3b64c110d7",
          "driver": "macvlan",
          "network_interface": "proxy",
          "created": "2024-11-03T12:17:56.16722358+01:00",
          "ipv6_enabled": false,
          "internal": false,
          "dns_enabled": false,
          "ipam_options": {
               "driver": "dhcp"
          }
     }
]
```

