#------------------------------------------------#
# Initialization a minion script
# Maintainer: Yongbok Kim (ruo91@yongbok.net)
#------------------------------------------------#
#!/bin/bash

# Binary
FLANNEL="/bin/flannel.sh"

# PID
DOCKER_PID="$(ps -e | grep 'docker' | awk '{ printf $1 "\n" }')"

# kill docker
echo "Kill Docker..." && sleep 1
kill $DOCKER_PID
echo "done" && sleep 2

# Flannel
$FLANNEL flannel start && sleep 2
  
# Delete docker bridge
ip link set dev docker0 down && sleep 2
brctl delbr docker0 && sleep 2

# Start docker
service docker start
