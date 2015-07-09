#!/bin/bash
# Kubernetes
KUBERNETES_HOME=/opt/kubernetes
PATH=$PATH:$KUBERNETES_HOME/server/bin
kube-scheduler \
--address=0.0.0.0 \
--port=10251 \
--master=$(ifconfig eth0 | grep 'inet addr:' | cut -d ':' -f 2 | awk '{ print $1 }'):8080 \
> /tmp/scheduler.log 2>&1 &
