#!/bin/bash
# Kubernetes
KUBERNETES_HOME=/opt/kubernetes
PATH=$PATH:$KUBERNETES_HOME/server/bin
kube-proxy --master=$(cat /etc/hosts | grep 'kubernetes-master' | awk '{ printf $1 }'):8080 \
> /tmp/proxy.log 2>&1 &
