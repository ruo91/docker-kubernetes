#------------------------------------------------#
# Flannel start script
# Maintainer: Yongbok Kim (ruo91@yongbok.net)
#------------------------------------------------#
#!/bin/bash
### Global ###
# Flannel
FLANNEL_HOME=/opt/flannel
PATH=$PATH:$FLANNEL_HOME/bin

# Flannel options
IFACE="eth1"
ETCD_PORT="4001"
ETCD_PREFIX="/overlay/network"
ETCD_SERVER="http://172.17.1.1:$ETCD_PORT,http://172.17.1.2:$ETCD_PORT,http://172.17.1.3:$ETCD_PORT"

# Logs
FLANNEL_LOGS="/tmp/flannel.log"
FLANNELD_LOGS="/tmp/flanneld.log"

# PID
FLANNELD_PID="$(ps -e | grep 'flanneld' | awk '{ printf $1 "\n" }')"

# Functions
function f_flannel {
  echo "Start Flannel Server..."  && sleep 1
  flanneld \
  -iface=$IFACE \
  -log_dir="$FLANNEL_LOGS" \
  -etcd-prefix="$ETCD_PREFIX" \
  -etcd-endpoints="$ETCD_SERVER" \
  --v=0 > $FLANNELD_LOGS 2>&1 &
  echo "done"
}

# Function of manual
function f_apiserver_manual {
  echo -ne "\033[33m- Interface \033[0m \n"
  echo -ne "\033[33m- ex) $IFACE \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read IFACE
  echo

  echo -ne "\033[33m- ETCD Prefix \033[0m \n"
  echo -ne "\033[33m- ex) $ETCD_PREFIX \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read ETCD_PREFIX
  echo

  echo -ne "\033[33m- ETCD Server \033[0m \n"
  echo -ne "\033[33m- ex)$ETCD_SERVER \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_ETCD_SERVER
  echo

  echo "Start Flannel Server..."  && sleep 1
  flanneld \
  -iface=$IFACE \
  -log_dir="$FLANNEL_LOGS" \
  -etcd-prefix="$ETCD_PREFIX" \
  -etcd-endpoints="$ETCD_SERVER" \
  --v=0 > $FLANNELD_LOGS 2>&1 &
  echo "done"
}

function f_kill_of_process {
  if [[ "$ARG_2" == "f" || "$ARG_2" == "flannel" ]]; then
      echo "Kill of Flanneld..." && sleep 1
      kill -9 $FLANNELD_PID
      echo "done"

  else
      echo "Not found PIDs"
  fi
}

function f_help {
  echo "Usage: $ARG_0 [Options] [Arguments]"
  echo
  echo "- Options"
  echo "f, flannel	: Flannel"
  echo "k, kill		: kill of process"
  echo
  echo "- Arguments"
  echo "s, start	: Start commands"
  echo "m, manual	: Manual commands"
  echo
  echo "f, flannel	: kill of flannel (k or kill option only.)"
  echo "		ex) $ARG_0 k f or $ARG_0 kill flannel"
  echo
}

# Main
ARG_0="$0"
ARG_1="$1"
ARG_2="$2"

case ${ARG_1} in
  f|flannel)
    if [[ "$ARG_2" == "s" || "$ARG_2" == "start"  ]]; then
        f_flannel

    elif [[ "$ARG_2" == "m"  ||  "ARG_2" == "manual" ]]; then
        f_flannel_manual

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
