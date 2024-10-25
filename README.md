# ovs_bridge
- create openvswitch bridges and tagged vlans without accessing your machine manually!
- only a single physical NIC is required and you wont break ssh connection!
- ji_podhead.ovs_bridge will apply your settings, wait for your machine to reboot with the applied configuration 
- fully automated, so you can continue using those vlans and without accessing the machines/hosts manually
- ji_podhead.ovs_bridge will also create a libvirt Virtual Network for you 
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
<center><b>
we will not add the physical nic to the ovs bridge just yet!!
</b></center>


```yaml
---
- hosts: <your host>
  gather_facts: no
  become: true
  become_method: sudo
  collections:
    - ji_podhead.ovs_bridge

  tasks:

  - name: create the bridge
    import_role: 
      name: ji_podhead.ovs_bridge.create_bridge
    vars:
      ovs_bridge_connection: vlanbr_connection
      ovs_bridge_interface: vlanbr
      connection_port: connection_port
      interface_port: interface_port
      autoconnect: "yes"
      ipv4_method: static
      ipv4_address: 192.168.1.100/24
      ipv4_gateway: "192.168.1.1"

  
  - name: add vlans
    import_role: 
      name: ji_podhead.ovs_bridge.add_vlans
    vars:
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
```
- we have not added a IP to our vlanbr and we have not added our nic to our bridge as well, since we dont want to loose our ssh connection.
- we will do this in the next step, but first lets check out the results
## Result
```bash
$ nmcli con show
```
 ```yaml
    NAME                            UUID                                  TYPE           DEVICE            
    vlan-con-1                      270dd2b9-10d5-4458-ba32-e6089f94aae9  ovs-interface  vlan1             
    vlan-con-2                      85978b84-f216-435e-a017-ecd24bb0afd3  ovs-interface  vlan2             
    ovs-bridge-vlanbr_connection    8511136c-5778-4120-8c55-f77e3842ea36  ovs-bridge     vlanbr_connection 
    ovs-slave-connection_port       0a553bb0-4570-4ab9-8049-3828dafa1be9  ovs-port       connection_port   
    ovs-slave-interface_port        dec50f48-5a84-41c0-8253-ad49e314ee48  ovs-port       interface_port    
    vlan-port-1                     067d7ed3-a522-4bb6-9850-bd2663161a08  ovs-port       vlan1             
    vlan-port-2                     eed6fb76-a5b8-48a2-b9f6-9c9bd84f9da4  ovs-port       vlan2             
    ovs-slave-vlanbr                61c794a0-7dc6-4d38-b142-8e24d0699c7c  ovs-interface  vlanbr            
    lo                              34689ed1-13f2-4e1f-93cb-19e9f0ab750d  loopback       lo                
    enp2s0                          419acba5-e8e2-412a-881e-960009e846b8  ethernet       enp2s0            
    Kabelgebundene Verbindung 3     f317fa68-bce0-3669-90a1-6ca4c83df142  ethernet       --                
    ovs-bridge-vlanbr_connection-1  b6195711-4a37-4019-8e1c-149df5a7c62a  ovs-bridge     --                
    ovs-bridge-vlanbr_connection-2  767b165d-a05b-46d0-8938-663d6aee7e97  ovs-bridge     --                
    ovs-slave-connection_port-1     1c822758-d068-4eae-93a7-e09abac6a9cd  ovs-port       --                
    ovs-slave-connection_port-2     e1c5fedf-3496-42d0-ba91-f636fe2c24b8  ovs-port       --                
    ovs-slave-interface_port-1      196df3df-79da-43bf-9b24-2ccf82fe4bb9  ovs-port       --                
    ovs-slave-interface_port-2      a0ae71de-6d92-474c-bb31-d28a656b862f  ovs-port       --                
    ovs-slave-vlanbr-1              7dcaeec9-08db-4bfa-90fa-75a1e713e0dc  ovs-interface  --                
    ovs-slave-vlanbr-2              bbb16daf-e51b-4b22-a618-33f57dfece2c  ovs-interface  --                
  ```

----
```bash
ifconfig
```
  ```yaml
    enp2s0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.1.100  netmask 255.255.255.0  broadcast 0.0.0.0
            ether 40:b0:76:46:6f:76  txqueuelen 1000  (Ethernet)
            RX packets 2079  bytes 1056085 (1.0 MiB)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 1377  bytes 169162 (165.1 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
            device interrupt 16  

    lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
            inet 127.0.0.1  netmask 255.0.0.0
            inet6 ::1  prefixlen 128  scopeid 0x10<host>
            loop  txqueuelen 1000  (Lokale Schleife)
            RX packets 2934  bytes 584948 (571.2 KiB)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 2934  bytes 584948 (571.2 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

    vlan1: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.7.1  netmask 255.255.255.0  broadcast 192.168.7.255
            inet6 fe80::e4:7a77:3c77:8ab3  prefixlen 64  scopeid 0x20<link>
            ether 5a:ff:b8:64:48:84  txqueuelen 1000  (Ethernet)
            RX packets 0  bytes 0 (0.0 B)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 30  bytes 3620 (3.5 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

    vlan2: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
            inet 192.168.8.1  netmask 255.255.255.0  broadcast 192.168.8.255
            inet6 fe80::b9ea:1728:2ee:2300  prefixlen 64  scopeid 0x20<link>
            ether e2:5e:0a:e3:31:46  txqueuelen 1000  (Ethernet)
            RX packets 0  bytes 0 (0.0 B)
            RX errors 0  dropped 0  overruns 0  frame 0
            TX packets 28  bytes 3430 (3.3 KiB)
            TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
  ```
  - notice that our vlanbr interface is not et listed here, because its an inactive connection. 
  - the reason why its inactive is that its connection is inactive
  - however it already show up using `$ ip a` command
    ```yaml
        420: vlanbr: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
        link/ether 0a:db:8a:b1:90:e3 brd ff:ff:ff:ff:ff:ff
        inet6 fe80::437b:60cb:d15:1219/64 scope link noprefixroute 
        valid_lft forever preferred_lft forever
    ```
    