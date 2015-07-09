#!/bin/bash
# Kubernetes
KUBERNETES_HOME=/opt/kubernetes
PATH=$PATH:$KUBERNETES_HOME/server/bin
kube-apiserver \
--port=8080 \
--address=0.0.0.0 \
--kubelet_port=10250 \
--portal_net="10.0.42.1/16" \
--etcd_servers=http://etcd-cluster-0:4001,http://etcd-cluster-1:4001,http://etcd-cluster-2:4001 \
> /tmp/api-server.log 2>&1 &
