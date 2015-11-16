#
# Dockerfile - Google Kubernetes
#
# - Build
# docker build --rm -t kubernetes:minion -f 03_kubernetes-minion .
#
# - Run
# docker run -d --name="kubernetes-minion-0" -h "kubernetes-minion-0" --privileged=true -v /dev:/dev -v /sys:/sys -v /lib/modules:/lib/modules kubernetes:minion
# docker run -d --name="kubernetes-minion-1" -h "kubernetes-minion-1" --privileged=true -v /dev:/dev -v /sys:/sys -v /lib/modules:/lib/modules kubernetes:minion
#
# - SSH
# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' kubernetes-minion-0`
# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' kubernetes-minion-1`
#
# Use the base images
FROM ubuntu:15.04
MAINTAINER Yongbok Kim <ruo91@yongbok.net>

# Change the repository
#RUN sed -i 's/archive.ubuntu.com/kr.archive.ubuntu.com/g' /etc/apt/sources.list

# The last update and install package for docker
RUN apt-get update && apt-get install -y docker.io lxc iptables apparmor supervisor openssh-server nano curl git-core build-essential net-tools iputils-ping bridge-utils

# Docker in Docker
ADD conf/docker/default_docker /etc/default/docker
ADD https://raw.githubusercontent.com/jpetazzo/dind/master/wrapdocker /bin/wrapdocker
RUN chmod +x /bin/wrapdocker

# Volume mount
# Issue    : There are no more loopback devices available.
# Solution : docker run -v /dev/:/dev
VOLUME /var/run
VOLUME /var/lib/docker

# Variable
ENV SRC_DIR /opt
WORKDIR $SRC_DIR

# GO Language
ENV GO_ARCH linux-amd64
ENV GOROOT $SRC_DIR/go
ENV PATH $PATH:$GOROOT/bin
RUN curl -XGET https://github.com/golang/go/tags | grep tag-name > /tmp/golang_tag \
 && sed -e 's/<[^>]*>//g' /tmp/golang_tag > /tmp/golang_ver \
 && GO_VER=`sed -e 's/      go/go/g' /tmp/golang_ver | head -n 1` && rm -f /tmp/golang_* \
 && curl -LO "https://storage.googleapis.com/golang/$GO_VER.$GO_ARCH.tar.gz" \
 && tar -C $SRC_DIR -xzf go*.tar.gz && rm -rf go*.tar.gz \
 && echo '' >> /etc/profile \
 && echo '# Golang' >> /etc/profile \
 && echo "export GOROOT=$GOROOT" >> /etc/profile \
 && echo 'export PATH=$PATH:$GOROOT/bin' >> /etc/profile \
 && echo '' >> /etc/profile

# Flannel
ENV FLANNEL_HOME $SRC_DIR/flannel
ENV PATH $PATH:$FLANNEL_HOME/bin
RUN git clone https://github.com/coreos/flannel.git \
 && cd flannel && ./build \
 && echo '# flannel'>>/etc/profile \
 && echo "export FLANNEL_HOME=/opt/flannel">>/etc/profile \
 && echo 'export PATH=$PATH:$FLANNEL_HOME/bin'>>/etc/profile \
 && echo ''>>/etc/profile

# Google - Kubernetes
ENV KUBERNETES_HOME $SRC_DIR/kubernetes
ENV PATH $PATH:$KUBERNETES_HOME/server/bin
ADD kubernetes-server-linux-amd64.tar.gz $SRC_DIR
RUN echo '# Kubernetes' >> /etc/profile \
 && echo "export KUBERNETES_HOME=$KUBERNETES_HOME" >> /etc/profile \
 && echo 'export PATH=$PATH:$KUBERNETES_HOME/server/bin' >> /etc/profile \
 && echo '' >> /etc/profile

# kubernetes minion & flannel scripts
ADD conf/network/00_flannel.sh /bin/flannel.sh
ADD conf/cluster/02_minion.sh /bin/minion.sh
ADD conf/cluster/03_minion_init.sh /bin/minion-init.sh
RUN chmod a+x /bin/flannel.sh /bin/minion.sh /bin/minion-init.sh

# Supervisor
RUN mkdir -p /var/log/supervisor
ADD conf/supervisord/01_minion.conf /etc/supervisor/conf.d/supervisord.conf

# SSH
RUN mkdir /var/run/sshd
RUN sed -i 's/without-password/yes/g' /etc/ssh/sshd_config
RUN sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
RUN sed -i 's/\#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config

# Set the root password for ssh
RUN echo 'root:kubernetes' |chpasswd

# Port
EXPOSE 22 8080

# Daemon
CMD ["/usr/bin/supervisord"]
