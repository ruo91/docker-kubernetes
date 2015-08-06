#------------------------------------------------#
# etcd cluster script
# Maintainer: Yongbok Kim (ruo91@yongbok.net)
#------------------------------------------------#
#!/bin/bash
### Global ###
# ETCD
ETCD=/opt/etcd
PATH=$PATH:$ETCD

# Cluster
ETCD_CLUSTER_IP="0.0.0.0"
ETCD_CLUSTER_STATE="new"
ETCD_CLUSTER_NAME_0="cluster-0"
ETCD_CLUSTER_NAME_1="cluster-1"
ETCD_CLUSTER_NAME_2="cluster-2"
ETCD_CLUSTER_TOKEN="etcd-cluster"
ETCD_DATA_DIR="/tmp/etcd"
ETCD_ADVERTISE_PEER_IP="$(ip a s | grep 'eth1' | grep 'inet' | cut -d '/' -f 1 | awk '{ print $2 }')"
ETCD_INITIAL_CLUSTER="$ETCD_CLUSTER_NAME_0=http://172.17.1.1:2380,$ETCD_CLUSTER_NAME_1=http://172.17.1.2:2380,$ETCD_CLUSTER_NAME_2=http://172.17.1.3:2380"

# Logs
ETCD_LOGS="/tmp/etcd-cluster.log"

# PID
ETCD_PID="$(ps -e | grep 'etcd' | awk '{ printf $1 "\n" }')"

# Function
function f_etcd {
  echo "Start ETCD..."  && sleep 1
  if [ "$ETCD_ADVERTISE_PEER_IP"  == "172.17.1.1" ]; then
      etcd \
      --name "$ETCD_CLUSTER_NAME_0" \
      --data-dir "$ETCD_DATA_DIR" \
      --listen-peer-urls "http://$ETCD_CLUSTER_IP:2380" \
      --listen-client-urls "http://$ETCD_CLUSTER_IP:4001" \
      --initial-cluster-state "$ETCD_CLUSTER_STATE" \
      --initial-cluster-token "$ETCD_CLUSTER_TOKEN" \
      --initial-advertise-peer-urls "http://$ETCD_ADVERTISE_PEER_IP:2380" \
      --advertise-client-urls "http://$ETCD_CLUSTER_IP:4001" \
      --initial-cluster "$ETCD_INITIAL_CLUSTER" \
      > $ETCD_LOGS 2>&1 &
      echo "done"

  elif [ "$ETCD_ADVERTISE_PEER_IP"  == "172.17.1.2" ]; then
      etcd \
      --name "$ETCD_CLUSTER_NAME_1" \
      --data-dir "$ETCD_DATA_DIR" \
      --listen-peer-urls "http://$ETCD_CLUSTER_IP:2380" \
      --listen-client-urls "http://$ETCD_CLUSTER_IP:4001" \
      --initial-cluster-state "$ETCD_CLUSTER_STATE" \
      --initial-cluster-token "$ETCD_CLUSTER_TOKEN" \
      --initial-advertise-peer-urls "http://$ETCD_ADVERTISE_PEER_IP:2380" \
      --advertise-client-urls "http://$ETCD_CLUSTER_IP:4001" \
      --initial-cluster "$ETCD_INITIAL_CLUSTER" \
      > $ETCD_LOGS 2>&1 &
      echo "done"

  elif [ "$ETCD_ADVERTISE_PEER_IP"  == "172.17.1.3" ]; then
      etcd \
      --name "$ETCD_CLUSTER_NAME_2" \
      --data-dir "$ETCD_DATA_DIR" \
      --listen-peer-urls "http://$ETCD_CLUSTER_IP:2380" \
      --listen-client-urls "http://$ETCD_CLUSTER_IP:4001" \
      --initial-cluster-state "$ETCD_CLUSTER_STATE" \
      --initial-cluster-token "$ETCD_CLUSTER_TOKEN" \
      --initial-advertise-peer-urls "http://$ETCD_ADVERTISE_PEER_IP:2380" \
      --advertise-client-urls "http://$ETCD_CLUSTER_IP:4001" \
      --initial-cluster "$ETCD_INITIAL_CLUSTER" \
      > $ETCD_LOGS 2>&1 &
      echo "done"

  else
      echo "IP address does not matching."
  fi
}

# Function of manual
function f_etcd_manual {
  echo -ne "\033[33m- Cluster Name \033[0m \n"
  echo -ne "\033[33m- ex) cluster-0 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read ETCD_CLUSTER_NAME
  echo

  echo -ne "\033[33m- Initial Cluster URL \033[0m \n"
  echo -ne "\033[33m- ex) cluster-0=http://172.17.1.1:2380,cluster-1=http://172.17.1.2:2380,cluster-2=http://172.17.1.3:2380 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read ETCD_INITIAL_CLUSTER
  echo

  echo "Start ETCD..."  && sleep 1
  etcd \
  --name "$ETCD_CLUSTER_NAME" \
  --data-dir "$ETCD_DATA_DIR" \
  --listen-peer-urls "http://$ETCD_CLUSTER_IP:2380" \
  --listen-client-urls "http://$ETCD_CLUSTER_IP:4001" \
  --initial-cluster-state "$ETCD_CLUSTER_STATE" \
  --initial-cluster-token "$ETCD_CLUSTER_TOKEN" \
  --initial-advertise-peer-urls "http://$ETCD_ADVERTISE_PEER_IP:2380" \
  --advertise-client-urls "http://$ETCD_CLUSTER_IP:4001" \
  --initial-cluster "$ETCD_INITIAL_CLUSTER" \
  > $ETCD_LOGS 2>&1 &
  echo "done"
}

function f_kill_of_process {
  if [[ "$ARG_2" == "e" || "$ARG_2" == "etcd" ]]; then
      echo "Kill of ETCD..." && sleep 1
      kill -9 $ETCD_PID
      echo "done"

  else
      echo "Not found PIDs"
  fi
}

function f_help {
  echo "Usage: $ARG_0 [Options] [Arguments]"
  echo
  echo "- Options"
  echo "e, etcd		: etcd"
  echo "k, kill		: kill of process"
  echo
  echo "- Arguments"
  echo "s, start	: Start commands"
  echo "m, manual	: Manual commands"
  echo "e, etcd		: kill of etcd (k or kill option only.)"
  echo "		ex) $ARG_0 k e or $ARG_0 kill etcd"
  echo
}

# Main
ARG_0="$0"
ARG_1="$1"
ARG_2="$2"

case ${ARG_1} in
  e|etcd)
    if [[ "$ARG_2" == "s" || "$ARG_2" == "start"  ]]; then
        f_etcd

    elif [[ "$ARG_2" == "m" || "$ARG_2" == "manual"  ]]; then
        f_etcd_manual

    else
        f_help
    fi
  ;;

  k|kill)
        f_kill_of_process
  ;;

  *)
    f_help
  ;;

esac
