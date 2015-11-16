#
# Dockerfile - Google Kubernetes
#
# - Build
# docker build --rm -t kubernetes:client -f 01_kubernetes-client .
#
# - Run
# docker run -d --name="kubernetes-client" -h "kubernetes-client" kubernetes:client
#
# - SSH
# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' kubernetes-client`

# Use the base images
FROM ubuntu:15.04
MAINTAINER Yongbok Kim <ruo91@yongbok.net>

# Change the repository
#RUN sed -i 's/archive.ubuntu.com/kr.archive.ubuntu.com/g' /etc/apt/sources.list

# The last update and install package for docker
RUN apt-get update && apt-get install -y supervisor openssh-server nano net-tools iputils-ping

# Variable
ENV SRC_DIR /opt
WORKDIR $SRC_DIR

# Google - Kubernetes
ENV KUBERNETES_HOME $SRC_DIR/kubernetes
ENV PATH $PATH:$KUBERNETES_HOME/client/bin
ADD kubernetes-client-linux-amd64.tar.gz $SRC_DIR
ADD conf/cluster/06_nginx.yaml /opt/nginx.yaml
ADD https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/kube-ui/kube-ui-rc.yaml /opt/kube-ui-rc.yaml
ADD https://raw.githubusercontent.com/kubernetes/kubernetes/master/cluster/addons/kube-ui/kube-ui-svc.yaml /opt/kube-ui-svc.yaml
RUN echo '# Kubernetes' >> /etc/profile \
 && echo "export KUBERNETES_HOME=$KUBERNETES_HOME" >> /etc/profile \
 && echo 'export PATH=$PATH:$KUBERNETES_HOME/client/bin' >> /etc/profile \
 && echo '' >> /etc/profile

# Supervisor
RUN mkdir -p /var/log/supervisor
ADD conf/supervisord/00_default.conf /etc/supervisor/conf.d/supervisord.conf

# SSH
RUN mkdir /var/run/sshd
RUN sed -i 's/without-password/yes/g' /etc/ssh/sshd_config
RUN sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
RUN sed -i 's/\#AuthorizedKeysFile/AuthorizedKeysFile/g' /etc/ssh/sshd_config

# Set the root password for ssh
RUN echo 'root:kubernetes' |chpasswd

# Port
EXPOSE 22

# Daemon
CMD ["/usr/bin/supervisord"]
