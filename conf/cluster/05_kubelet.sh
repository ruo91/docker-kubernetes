#!/bin/bash
# Kubernetes
KUBERNETES_HOME=/opt/kubernetes
PATH=$PATH:$KUBERNETES_HOME/server/bin

kubelet \
--address=0.0.0.0 \
--port=10250 \
--cadvisor_port=4194 \
--api_servers=$(cat /etc/hosts | grep 'kubernetes-master' | awk '{ printf $1 }'):8080 \
--hostname_override=$(ifconfig eth0 | grep 'inet addr:' | cut -d ':' -f 2 | awk '{ print $1 }') \
> /tmp/kubelet.log 2>&1 &
