#------------------------------------------------#
# Kubernetes start script
# Maintainer: Yongbok Kim (ruo91@yongbok.net)
#------------------------------------------------#
#!/bin/bash
### Global ###
# Kubernetes
K8S_HOME=/opt/kubernetes
PATH=$PATH:$K8S_HOME/server/bin

# Ports
K8S_ETCD_PORT="4001"
K8S_KUBELET_PORT="10250"
K8S_API_SERVER_PORT="8080"

# Address
K8S_API_SERVER="172.17.1.4"
K8S_POTAL_NET_CIDR="10.0.42.1/16"
K8S_COMMON_SERVER_ADDR="0.0.0.0"
K8S_ETCD_SERVER="http://172.17.1.1:$K8S_ETCD_PORT,http://172.17.1.2:$K8S_ETCD_PORT,http://172.17.1.3:$K8S_ETCD_PORT"

# Logs
K8S_API_SERVER_LOGS="/tmp/apiserver.log"
K8S_SCHEDULER_LOGS="/tmp/scheduler.log"
K8S_CONTROLLER_LOGS="/tmp/controller-manager.log"

# PID
K8S_API_SERVER_PID="$(ps -e | grep 'kube-apiserver' | awk '{ printf $1 "\n" }')"
K8S_SCHEDULER_SERVER_PID="$(ps -e | grep 'kube-scheduler' | awk '{ printf $1 "\n" }')"
K8S_CONTROLLER_SERVER_PID="$(ps -e | grep 'kube-controller' | awk '{ printf $1 "\n" }')"

# Functions
function f_apiserver {
  echo "Start API Server..."  && sleep 1
  kube-apiserver \
  --port=$K8S_API_SERVER_PORT \
  --address=$K8S_COMMON_SERVER_ADDR \
  --kubelet_port=$K8S_KUBELET_PORT \
  --portal_net=$K8S_POTAL_NET_CIDR \
  --etcd_servers=$K8S_ETCD_SERVER \
  > $K8S_API_SERVER_LOGS 2>&1 &
  echo "done"
}

function f_scheduler {
  echo "Start Scheduler..." && sleep 1
  kube-scheduler \
  --address=$K8S_COMMON_SERVER_ADDR \
  --master=$K8S_API_SERVER:$K8S_API_SERVER_PORT \
  > $K8S_SCHEDULER_LOGS 2>&1 &
  echo "done"
}

function f_controller_manager {
  echo "Start Controller Manager..." && sleep 1
  kube-controller-manager \
  --address=$K8S_COMMON_SERVER_ADDR \
  --master=$K8S_API_SERVER:$K8S_API_SERVER_PORT \
  > $K8S_CONTROLLER_LOGS 2>&1 &
  echo "done"
}

# Function of manual
function f_apiserver_manual {
  echo -ne "\033[33m- API Server Port \033[0m \n"
  echo -ne "\033[33m- ex) 8080 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_API_SERVER_PORT
  echo

  echo -ne "\033[33m- API Server Service Address \033[0m \n"
  echo -ne "\033[33m- ex) 0.0.0.0 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_API_SERVICE_ADDR
  echo

  echo -ne "\033[33m- Kubelet Port \033[0m \n"
  echo -ne "\033[33m- ex) 10250 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_KUBELET_PORT
  echo

  echo -ne "\033[33m- Potal Net CIDR \033[0m \n"
  echo -ne "\033[33m- ex) 10.0.42.1/16 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_POTAL_NET_CIDR
  echo

  echo -ne "\033[33m- ETCD Server \033[0m \n"
  echo -ne "\033[33m- ex) http://172.17.1.1:4001,http://172.17.1.1:4001\033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_ETCD_SERVER
  echo

  echo "Start API Server..."  && sleep 1
  kube-apiserver \
  --port=$K8S_API_SERVER_PORT \
  --address=$K8S_API_SERVICE_ADDR \
  --kubelet_port=$K8S_KUBELET_PORT \
  --portal_net=$K8S_POTAL_NET_CIDR \
  --etcd_servers=$K8S_ETCD_SERVER \
  > $K8S_API_SERVER_LOGS 2>&1 &
  echo "done"
}

function f_scheduler_manual {
  echo -ne "\033[33m- API Server \033[0m \n"
  echo -ne "\033[33m- ex) 172.17.1.1:8080 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_API_SERVER
  echo

  echo -ne "\033[33m- Scheduler Service Address \033[0m \n"
  echo -ne "\033[33m- ex) 0.0.0.0 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_SCHEDULER_SERVICE_ADDR
  echo

  echo "Start Scheduler..." && sleep 1
  kube-scheduler \
  --address=$K8S_SCHEDULER_SERVICE_ADDR \
  --master=$K8S_API_SERVER \
  > $K8S_SCHEDULER_LOGS 2>&1 &
  echo "done"
}

function f_controller_manager_manual {
  echo -ne "\033[33m- API Server \033[0m \n"
  echo -ne "\033[33m- ex) 172.17.1.1:8080 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_API_SERVER
  echo

  echo -ne "\033[33m- Controller Manager Service Address \033[0m \n"
  echo -ne "\033[33m- ex) 0.0.0.0 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_CONTROLLER_SERVICE_ADDR
  echo

  echo "Start Controller Manager..." && sleep 1
  kube-controller-manager \
  --address=$K8S_CONTROLLER_SERVICE_ADDR \
  --master=$K8S_API_SERVER \
  > $K8S_CONTROLLER_LOGS 2>&1 &
  echo "done"
}

function f_kill_of_process {
  if [ "$ARG_2" == "all" ]; then
      echo "Kill of All Server..." && sleep 1
      kill -9 $K8S_API_SERVER_PID \
      $K8S_SCHEDULER_SERVER_PID \
      $K8S_CONTROLLER_SERVER_PID
      echo "done"

  elif [[ "$ARG_2" == "a" || "$ARG_2" == "api" ]]; then
      echo "Kill of API Server..." && sleep 1
      kill -9 $K8S_API_SERVER_PID
      echo "done"

 elif [[ "$ARG_2" == "s" || "$ARG_2" == "sd" ]]; then
      echo "Kill of Scheduler..." && sleep 1
      kill -9 $K8S_SCHEDULER_SERVER_PID
      echo "done"

 elif [[ "$ARG_2" == "c" || "$ARG_2" == "cm" ]]; then
      echo "Kill of Controller Manager..." && sleep 1
      kill -9 $K8S_CONTROLLER_SERVER_PID
      echo "done"

  else
      echo "Not found PIDs"
  fi
}

function f_help {
  echo "Usage: $ARG_0 [Options] [Arguments]"
  echo
  echo "- Options"
  echo "a, api		: apiserver"
  echo "s, sd		: scheduler"
  echo "c, cm		: controller manager"
  echo "k, kill		: kill of process"
  echo
  echo "- Arguments"
  echo "s, start	: Start commands"
  echo "m, manual	: Manual commands"
  echo
  echo "all		: kill of all server (k or kill option only.)"
  echo "		ex) $ARG_0 k all or $ARG_0 kill all"
  echo
  echo "a, api		: kill of apiserver (k or kill option only.)"
  echo "		ex) $ARG_0 k a or $ARG_0 kill api"
  echo
  echo "s, sd		: kill of scheduler (k or kill option only.)"
  echo "		ex) $ARG_0 k s or $ARG_0 kill sd"
  echo
  echo "c, cm		: kill of controller manager (k or kill option only)"
  echo "		ex) $ARG_0 k c or $ARG_0 kill cm"
  echo
}

# Main
ARG_0="$0"
ARG_1="$1"
ARG_2="$2"

case ${ARG_1} in
  a|api)
    if [[ "$ARG_2" == "s" || "$ARG_2" == "start"  ]]; then
        f_apiserver

    elif [[ "$ARG_2" == "m"  ||  "ARG_2" == "manual" ]]; then
        f_apiserver_manual

    else
        f_help
    fi
  ;;

  s|sd)
    if [[ "$ARG_2" == "s" || "$ARG_2" == "start"  ]]; then
        f_scheduler

    elif [[ "$ARG_2" == "m"  ||  "ARG_2" == "manual" ]]; then
        f_scheduler_manual

   else
       f_help
   fi
  ;;

  c|cm)
    if [[ "$ARG_2" == "s" || "$ARG_2" == "start"  ]]; then
        f_controller_manager

    elif [[ "$ARG_2" == "m"  ||  "ARG_2" == "manual" ]]; then
        f_controller_manager_manual

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