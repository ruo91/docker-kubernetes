#!/bin/bash
BRCTL="$(which brctl)"
BRIDGE_IFACE="br0"
FLANNEL_CIDR="$(ip a s flannel.1 | grep -v 'inet6' | grep 'inet' | cut -d ':' -f 2 | awk '{ print $2}' | sed 's/0\/16/1\/24/g')"

$BRCTL addbr $BRIDGE_IFACE && sleep 2
ip addr add $FLANNEL_CIDR dev $BRIDGE_IFACE && sleep 2
ip link set dev $BRIDGE_IFACE up && sleep 2
