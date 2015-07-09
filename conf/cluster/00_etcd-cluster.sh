#!/bin/bash
# etcd
ETCD="/opt/etcd"
PATH=$PATH:$ETCD

# cluster
CLUSTER_STATE="new"
CLUSTER_TOKEN="etcd-cluster"
CLUSTER_NAME_0="cluster-0"
CLUSTER_NAME_1="cluster-1"
CLUSTER_NAME_2="cluster-2"
CLUSTER_HOSTNAME_0=$(cat /etc/hosts | grep 'etcd-cluster-0' | awk '{ printf $1 "\n"}')
CLUSTER_HOSTNAME_1=$(cat /etc/hosts | grep 'etcd-cluster-1' | awk '{ printf $1 "\n"}')
CLUSTER_HOSTNAME_2=$(cat /etc/hosts | grep 'etcd-cluster-2' | awk '{ printf $1 "\n"}')
CLUSTER_IP="$(ifconfig eth0 | grep 'inet addr:' | cut -d ':' -f 2 | awk '{ print $1 }')"

# Issue: connection refused
# Solutions: --listen-client-urls http://0.0.0.0:4001
etcd \
--name "$CLUSTER_NAME_0" \
--data-dir "/tmp/etcd/$CLUSTER_NAME_0" \
--listen-peer-urls "http://$CLUSTER_IP:2380" \
--listen-client-urls "http://$CLUSTER_IP:4001" \
--initial-cluster-state "$CLUSTER_STATE" \
--initial-cluster-token "$CLUSTER_TOKEN" \
--initial-advertise-peer-urls "http://$CLUSTER_IP:2380" \
--advertise-client-urls "http://$CLUSTER_IP:4001" \
--initial-cluster "$CLUSTER_NAME_0=http://$CLUSTER_HOSTNAME_0:2380,$CLUSTER_NAME_1=http://$CLUSTER_HOSTNAME_1:2380,$CLUSTER_NAME_2=http://$CLUSTER_HOSTNAME_2:2380" \
> /tmp/etcd-cluster.log 2>&1 &
