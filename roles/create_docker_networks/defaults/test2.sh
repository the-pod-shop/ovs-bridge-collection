#!/bin/bash

# Funktion zum Löschen aller OVS-Interfaces
function delete_ovs_interfaces() {
    echo "Lösche alle OVS-Interfaces..."
    ovs-vsctl del-br $(ovs-vsctl list-br | tr '\n' ' ')
}

# Funktion zum Löschen aller OVS-Ports
function delete_ovs_ports() {
    echo "Lösche alle OVS-Ports..."
    ovs-vsctl del-port $(ovs-vsctl list-ports | tr '\n' ' ')
}

# Hauptlogik
echo "Vor dem Löschen:"
echo "Interfaces:"
ovs-vsctl list-ifaces
echo "Ports:"
ovs-vsctl list-ports

read -p "Sind Sie sicher, dass Sie alle OVS-Interfaces und Ports löschen möchten? (y/N) " -n 1 -r
echo    # Add a newline after the prompt

if [[ $REPLY =~ ^[Yy]$ ]]
then
    delete_ovs_interfaces
    delete_ovs_ports
    
    echo "Alle OVS-Interfaces und Ports wurden gelöscht."
else
    echo "Abgebrochen. Keine Änderungen vorgenommen."
fi

echo "Nach dem Löschen:"
echo "Interfaces:"
ovs-vsctl list-ifaces
echo "Ports:"
ovs-vsctl list-ports
