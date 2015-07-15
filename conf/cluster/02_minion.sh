#------------------------------------------------#
# Kubernetes minion start script
# Maintainer: Yongbok Kim (ruo91@yongbok.net)
#------------------------------------------------#
#!/bin/bash
### Global ###
# Kubernetes
K8S_HOME=/opt/kubernetes
PATH=$PATH:$K8S_HOME/server/bin

# Ports
K8S_CADVISOR_PORT="4194"
K8S_KUBELET_PORT="10250"
K8S_API_SERVER_PORT="8080"

# Address
K8S_API_SERVER="172.17.1.4"
K8S_COMMON_SERVER_ADDR="0.0.0.0"
K8S_HOST_OVERRIDE="$(ifconfig eth0 | grep 'inet addr:' | cut -d ':' -f 2 | awk '{ print $1 }')"

# Logs
K8S_PROXY_LOGS="/tmp/proxy.log"
K8S_KUBELET_LOGS="/tmp/kubelet.log"

# PID
K8S_PROXY_SERVER_PID="$(ps -e | grep 'kube-proxy' | awk '{ printf $1 "\n" }')"
K8S_KUBELET_SERVER_PID="$(ps -e | grep 'kubelet' | awk '{ printf $1 "\n" }')"

# Functions
function f_proxy {
  echo "Start Proxy..."  && sleep 1
  kube-proxy \
  --master=$K8S_API_SERVER:$K8S_API_SERVER_PORT \
  > $K8S_PROXY_LOGS 2>&1 &
  echo "done"
}

function f_kubelet {
  echo "Start Kubelet..." && sleep 1
  kubelet \
  --address=$K8S_COMMON_SERVER_ADDR \
  --port=$K8S_KUBELET_PORT \
  --cadvisor_port=$K8S_CADVISOR_PORT \
  --api_servers=$K8S_API_SERVER:$K8S_API_SERVER_PORT \
  --hostname_override=$K8S_HOST_OVERRIDE \
  > $K8S_KUBELET_LOGS 2>&1 &
  echo "done"
}

# Function of manual
function f_proxy_manual {
  echo -ne "\033[33m- API Server \033[0m \n"
  echo -ne "\033[33m- ex) 172.17.1.4:8080 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_API_SERVER
  echo

  echo "Start Proxy..."  && sleep 1
  kube-proxy \
  --master=$K8S_API_SERVER \
  > $K8S_PROXY_LOGS 2>&1 &
  echo "done"
}

function f_kubelet_manual {
  echo -ne "\033[33m- Kubelet Port \033[0m \n"
  echo -ne "\033[33m- ex) 10250 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_KUBELET_PORT
  echo

  echo -ne "\033[33m- cAdvisor Port \033[0m \n"
  echo -ne "\033[33m- ex) 4194 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_CADVISOR_PORT
  echo

  echo -ne "\033[33m- Kubelet Service Address \033[0m \n"
  echo -ne "\033[33m- ex) 0.0.0.0 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_KUBELET_SERVICE_ADDR
  echo

  echo -ne "\033[33m- API Server \033[0m \n"
  echo -ne "\033[33m- ex) 172.17.1.4:8080 \033[0m \n"
  echo -ne "\033[33m- Input: \033[0m"
  read K8S_API_SERVER
  echo

  echo "Start Kubelet..." && sleep 1
  kubelet \
  --port=$K8S_KUBELET_PORT \
  --cadvisor_port=$K8S_CADVISOR_PORT \
  --address=$K8S_KUBELET_SERVICE_ADDR \
  --api_servers=$K8S_API_SERVER \
  --hostname_override=$K8S_HOST_OVERRIDE \
  > $K8S_KUBELET_LOGS 2>&1 &
  echo "done"
}

function f_kill_of_process {
  if [ "$ARG_2" == "all" ]; then
      echo "Kill of All Server..." && sleep 1
      kill -9 $K8S_PROXY_SERVER_PID \
      $K8S_KUBELET_SERVER_PID
      echo "done"

  elif [[ "$ARG_2" == "p" || "$ARG_2" == "proxy" ]]; then
      echo "Kill of Proxy..." && sleep 1
      kill -9 $K8S_PROXY_SERVER_PID
      echo "done"

 elif [[ "$ARG_2" == "k" || "$ARG_2" == "kubelet" ]]; then
      echo "Kill of Kubelet..." && sleep 1
      kill -9 $K8S_KUBELET_SERVER_PID
      echo "done"

  else
      echo "Not found PIDs"
  fi
}

function f_help {
  echo "Usage: $ARG_0 [Options] [Arguments]"
  echo
  echo "- Options"
  echo "p, proxy	: proxy"
  echo "kb, kubelet	: kubelet"
  echo "k, kill		: kill of process"
  echo
  echo "- Arguments"
  echo "s, start	: Start commands"
  echo "m, manual	: Manual commands"
  echo
  echo "all		: kill of all server (k or kill option only.)"
  echo "		ex) $ARG_0 k all or $ARG_0 kill all"
  echo
  echo "p, proxy	: kill of apiserver (k or kill option only.)"
  echo "		ex) $ARG_0 k p or $ARG_0 kill proxy"
  echo
  echo "kb, kubelet	: kill of scheduler (k or kill option only.)"
  echo "		ex) $ARG_0 k kb or $ARG_0 kill kubelet"
  echo
}

# Main
ARG_0="$0"
ARG_1="$1"
ARG_2="$2"

case ${ARG_1} in
  p|proxy)
    if [[ "$ARG_2" == "s" || "$ARG_2" == "start"  ]]; then
        f_proxy

    elif [[ "$ARG_2" == "m"  ||  "ARG_2" == "manual" ]]; then
        f_proxy_manual

    else
        f_help
    fi
  ;;

  kb|kubelet)
    if [[ "$ARG_2" == "s" || "$ARG_2" == "start"  ]]; then
        f_kubelet

    elif [[ "$ARG_2" == "m"  ||  "ARG_2" == "manual" ]]; then
        f_kubelet_manual

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