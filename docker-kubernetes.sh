#------------------------------------------------#
# Docker kubernetes script
# Maintainer: Yongbok Kim (ruo91@yongbok.net)
#------------------------------------------------#
#!/bin/bash
### Global ###
DOCKER="$(which docker)"

# Image name
IMAGE_ETCD="kubernetes:etcd"
IMAGE_MASTER="kubernetes:master"
IMAGE_MINION="kubernetes:minion"
IMAGE_CLIENT="kubernetes:client"

# Container name
CONTAINER_ETCD="etcd-cluster"
CONTAINER_MASTER="kubernetes-master"
CONTAINER_MINION="kubernetes-minion"
CONTAINER_CLIENT="kubernetes-client"

# Dockerfiles
DOCKER_FILE_ETCD="00_kubernetes-etcd"
DOCKER_FILE_CLIENT="01_kubernetes-client"
DOCKER_FILE_MASTER="02_kubernetes-master"
DOCKER_FILE_MINION="03_kubernetes-minion"

# Functions
function f_build {
  echo "- Build coreos etcd" && sleep 1
  $DOCKER build --rm -t $IMAGE_ETCD -f $DOCKER_FILE_ETCD $(pwd)
  echo "done"
  echo

  echo "- Build kubernetes client" && sleep 1
  $DOCKER build --rm -t $IMAGE_CLIENT -f $DOCKER_FILE_CLIENT $(pwd)
  echo "done"
  echo

  echo "- Build kubernetes master" && sleep 1
  $DOCKER build --rm -t $IMAGE_MASTER -f $DOCKER_FILE_MASTER $(pwd)
  echo "done"
  echo

  echo "- Build kubernetes minion" && sleep 1
  $DOCKER build --rm -t $IMAGE_MINION -f $DOCKER_FILE_MINION $(pwd)
  echo "done"
  echo

  # Remove none images
  #f_none_rmi > /dev/null 2>&1
}

function f_run {
  DOCKER_IFACE="docker0"
  DOCKER_PIPEWORK="/bin/pipework"
  DOCKER_PIPEWORK_URL="https://raw.githubusercontent.com/jpetazzo/pipework/master/pipework"

  # ARP & SSH known hosts flush
  echo "- ARP & SSH known hosts flush"
  echo "├-- ARP"
  for (( i=1; i<8; i++ )); do
      arp -d 172.17.1.$i > /dev/null 2>&1
  done
  echo "└-- SSH known hosts"
  cat /dev/null > $HOME/.ssh/known_hosts
  echo "done"
  echo

  if [ -f  "$DOCKER_PIPEWORK" ]; then
      ## CoreOS ETCD x3 ##
      echo "- ETCD Cluster"
      for (( i=0; i<3; i++ )); do
          echo "├-- Run $CONTAINER_ETCD-$i"
          $DOCKER run -d --name="$CONTAINER_ETCD-$i" -h "$CONTAINER_ETCD-$i" $IMAGE_ETCD > /dev/null 2>&1
      done

      # Static IP
      echo "├-- Static IP Setting"
      $DOCKER_PIPEWORK $DOCKER_IFACE $CONTAINER_ETCD-0 172.17.1.1/16 > /dev/null 2>&1
      $DOCKER_PIPEWORK $DOCKER_IFACE $CONTAINER_ETCD-1 172.17.1.2/16 > /dev/null 2>&1
      $DOCKER_PIPEWORK $DOCKER_IFACE $CONTAINER_ETCD-2 172.17.1.3/16 > /dev/null 2>&1

      # Start etcd cluster
      for (( i=0; i<3; i++ )); do
          echo "├-- Start etcd #$i"
          $DOCKER exec $CONTAINER_ETCD-$i /bin/bash etcd-cluster.sh etcd start > /dev/null 2>&1
      done
      sleep 3

      # Flannel Setting
      ETCD_SERVER_1="$(docker inspect -f '{{ .NetworkSettings.IPAddress }}' etcd-cluster-0)"
      echo "└-- Flannel Setting"
      curl -L http://$ETCD_SERVER_1:4001/v2/keys/overlay/network/config -XPUT --data-urlencode value@conf/network/flannel.json > /dev/null 2>&1
      echo "done"
      echo

      ## Kubernetes Master ##
      echo "- Kubernetes Master"
      echo "├-- Run $CONTAINER_MASTER"
      $DOCKER run -d --name="$CONTAINER_MASTER" -h "$CONTAINER_MASTER" --privileged=true -v /dev:/dev -v /lib/modules:/lib/modules $IMAGE_MASTER > /dev/null 2>&1

      # Static IP
      echo "├-- Static IP Setting"
      $DOCKER_PIPEWORK $DOCKER_IFACE $CONTAINER_MASTER 172.17.1.4/16 > /dev/null 2>&1

      # Start Flannel
      echo "├-- Start Flannel"
      $DOCKER exec $CONTAINER_MASTER /bin/bash flannel.sh flannel start > /dev/null 2>&1

      # Add bridge
      echo "├-- Add Bridge"
      $DOCKER exec $CONTAINER_MASTER /bin/bash k8s_master_add_bridge.sh > /dev/null 2>&1

      # Start API, Scheduler, Controller Manager
      echo "├-- Start API Server"
      $DOCKER exec $CONTAINER_MASTER /bin/bash k8s.sh api start > /dev/null 2>&1
      sleep 3

      echo "├-- Start Scheduler"
      $DOCKER exec $CONTAINER_MASTER /bin/bash k8s.sh sd start > /dev/null 2>&1

      echo "└-- Start Controller Manager"
      $DOCKER exec $CONTAINER_MASTER /bin/bash k8s.sh cm start > /dev/null 2>&1
      echo "done"
      echo

      ## Kubernetes Minion x2 ##
      echo "- Kubernetes Minion"
      for (( i=0; i<2; i++ )); do
          echo "├-- Run $CONTAINER_MINION-$i"
          $DOCKER run -d --name="$CONTAINER_MINION-$i" -h "$CONTAINER_MINION-$i" --privileged=true -v /dev:/dev -v /sys:/sys -v /lib/modules:/lib/modules $IMAGE_MINION > /dev/null 2>&1
      done
      sleep 3

      # Static IP
      echo "├-- Static IP Setting"
      $DOCKER_PIPEWORK $DOCKER_IFACE $CONTAINER_MINION-0 172.17.1.5/16 > /dev/null 2>&1
      $DOCKER_PIPEWORK $DOCKER_IFACE $CONTAINER_MINION-1 172.17.1.6/16 > /dev/null 2>&1

      # Start Flannel
      echo "├-- Start Flannel"
      $DOCKER exec $CONTAINER_MINION-0 /bin/bash minion-init.sh > /dev/null 2>&1
      $DOCKER exec $CONTAINER_MINION-1 /bin/bash minion-init.sh > /dev/null 2>&1

      # Start Kubelet, Proxy
      echo "├-- Start Kubelet"
      $DOCKER exec $CONTAINER_MINION-0 /bin/bash minion.sh kubelet start > /dev/null 2>&1
      $DOCKER exec $CONTAINER_MINION-1 /bin/bash minion.sh kubelet start > /dev/null 2>&1

      echo "└-- Start Proxy"
      $DOCKER exec $CONTAINER_MINION-0 /bin/bash minion.sh proxy start > /dev/null 2>&1
      $DOCKER exec $CONTAINER_MINION-1 /bin/bash minion.sh proxy start > /dev/null 2>&1
      echo "done"
      echo

      # Kubernetes Client
      echo "- Kubernetes Client"
      echo "├-- Run $CONTAINER_CLIENT"
      $DOCKER run -d --name="$CONTAINER_CLIENT" -h "$CONTAINER_CLIENT" $IMAGE_CLIENT > /dev/null 2>&1

      # Static IP
      echo "└-- Static IP Setting"
      $DOCKER_PIPEWORK $DOCKER_IFACE $CONTAINER_CLIENT 172.17.1.7/16 > /dev/null 2>&1
      echo "done"
      echo

      # Web UI
      KUBE_UI_RC="kubectl create -f /opt/kube-ui-rc.yaml --namespace=kube-system -s 172.17.1.4:8080"
      KUBE_UI_SVC="kubectl create -f /opt/kube-ui-svc.yaml --namespace=kube-system -s 172.17.1.4:8080"

      echo "- Web UI"
      echo "├-- Create Kube UI RC"
      $DOCKER exec $CONTAINER_CLIENT $KUBE_UI_RC > /dev/null 2>&1

      echo "├-- Create Kube UI SVC"
      $DOCKER exec $CONTAINER_CLIENT $KUBE_UI_SVC > /dev/null 2>&1
      echo "└-- URL: http://172.17.1.4:8080/"
      echo "done"
      echo

  else
      curl -o $DOCKER_PIPEWORK -L "$DOCKER_PIPEWORK_URL" > /dev/null 2>&1
      chmod a+x $DOCKER_PIPEWORK

      # Recusive f_run
      f_run
  fi
}

function f_none_rmi {
  echo "- Remove <none> images..." && sleep 1

  # Remove none images
  $DOCKER rmi $(docker images | grep '<none>' | awk '{ printf $3 " "}') > /dev/null 2>&1
  echo "done"
  echo
}

function f_stop_rm {
  echo "- Stop & Remove all containers..." && sleep 1

  # Stop
  $DOCKER stop $CONTAINER_ETCD-0 $CONTAINER_ETCD-1 $CONTAINER_ETCD-2 \
  $CONTAINER_MASTER $CONTAINER_MINION-0 $CONTAINER_MINION-1 $CONTAINER_CLIENT > /dev/null 2>&1

  # Remove
  $DOCKER rm $CONTAINER_ETCD-0 $CONTAINER_ETCD-1 $CONTAINER_ETCD-2 \
  $CONTAINER_MASTER $CONTAINER_MINION-0 $CONTAINER_MINION-1 $CONTAINER_CLIENT > /dev/null 2>&1
 
  # Remove none images
  #f_none_rmi
  echo "done"
  echo
}

function f_help {
  echo "Usage: $ARG_0 [Options] [Arguments]"
  echo
  echo "- Options"
  echo "b, build	: Build containers"
  echo "r, run		: Run containers"
  echo "sr		: Stop & Remove all containers"
  echo "none		: Remove <none> images"
  echo
  echo "- Arguments"
  echo "y, yes		:  build, run, sr option only"
  echo
  echo "rm, rmi		: Remove <none> images (none option only.)"
  echo "		ex) $ARG_0 n rm or $ARG_0 none rmi"
  echo
}

# Main
ARG_0="$0"
ARG_1="$1"
ARG_2="$2"

case ${ARG_1} in
  b|build)
    if [[ "$ARG_2" == "y" || "$ARG_2" == "yes"  ]]; then
        f_build

    else
        f_help
    fi
  ;;

  r|run)
    if [[ "$ARG_2" == "y" || "$ARG_2" == "yes"  ]]; then
        f_run

   else
       f_help
   fi
  ;;

  sr)
    if [[ "$ARG_2" == "y" || "$ARG_2" == "yes"  ]]; then
        f_stop_rm

    else
        f_help
    fi
  ;;

  n|none)
    if [[ "$ARG_2" == "rm" || "$ARG_2" == "rmi"  ]]; then
        f_none_rmi

    else
        f_help
    fi
  ;;

  *)
    f_help
  ;;
esac
