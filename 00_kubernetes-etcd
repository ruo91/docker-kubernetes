#
# Dockerfile - Google Kubernetes: etcd cluster
#
# - Build
# docker build --rm -t kubernetes:etcd -f 00_kubernetes-etcd .
#
# - Run
# docker run -d --name="etcd-cluster-0" -h "etcd-cluster-0" kubernetes:etcd
# docker run -d --name="etcd-cluster-1" -h "etcd-cluster-1" kubernetes:etcd
# docker run -d --name="etcd-cluster-2" -h "etcd-cluster-2" kubernetes:etcd
#
# - SSH
# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' etcd-cluster-0`
# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' etcd-cluster-1`
# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' etcd-cluster-2`

# Use the base images
FROM ubuntu:16.04
MAINTAINER Yongbok Kim <ruo91@yongbok.net>

# Change the repository
RUN sed -i 's/archive.ubuntu.com/ftp.daumkakao.com/g' /etc/apt/sources.list

# The last update and install package for docker
RUN apt-get update && apt-get install -y supervisor openssh-server git-core curl nano build-essential

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

# etcd
ENV ETCD $SRC_DIR/etcd
ENV PATH $PATH:$ETCD
ENV ETCD_RELEASE_VER release-2.3
RUN git clone https://github.com/coreos/etcd $SRC_DIR/etcd-source \
 && cd $SRC_DIR/etcd-source \
 && git checkout $ETCD_RELEASE_VER \
 && ./build && mv bin $ETCD \
 && cd $SRC_DIR && rm -rf $SRC_DIR/etcd-source \
 && echo '# etcd' >> /etc/profile \
 && echo "export ETCD=$ETCD" >> /etc/profile \
 && echo 'export PATH=$PATH:$ETCD' >> /etc/profile \
 && echo '' >> /etc/profile

# etcd cluster scripts
ADD conf/cluster/00_etcd-cluster.sh /bin/etcd-cluster.sh
RUN chmod a+x /bin/etcd-cluster.sh

# Supervisor
RUN mkdir -p /var/log/supervisor
ADD conf/supervisord/00_default.conf /etc/supervisor/conf.d/supervisord.conf

# SSH
RUN mkdir /var/run/sshd
RUN sed -i '/^#UseLogin/ s:.*:UseLogin yes:' /etc/ssh/sshd_config
RUN sed -i 's/\#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config
RUN sed -i '/^PermitRootLogin/ s:.*:PermitRootLogin yes:' /etc/ssh/sshd_config

# Set the root password for ssh
RUN echo 'root:kubernetes' |chpasswd

# Port
EXPOSE 22 2379 2380 4001

# Daemon
CMD ["/usr/bin/supervisord"]
