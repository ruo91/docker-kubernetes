#!/bin/bash
# Kubernetes
KUBERNETES_HOME=/opt/kubernetes
PATH=$PATH:$KUBERNETES_HOME/server/bin
kube-controller-manager \
--address=0.0.0.0 \
--master=$(ifconfig eth0 | grep 'inet addr:' | cut -d ':' -f 2 | awk '{ print $1 }'):8080 \
> /tmp/controller-manager.log 2>&1 &
