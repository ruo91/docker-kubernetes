Dockerfile - Google Kubernetes (test only)
=====================================
![0]

# - About Kubernetes?
------------------
Google의 Container 관리 도구인 Kubernetes를 Docker를 사용해서, 물리 서버 1대 만으로도 테스트를 해볼 수 있도록 만들어 봤습니다.
Kubernetes의 대해서는 아래 주소 또는 구글을 통해 참고 하시기 바랍니다.

link: http://www.yongbok.net/blog/google-kubernetes-container-cluster-manager/

#### - Clone
------------
Github 저장소에서 Dockerfile을 받아 옵니다.
```sh
root@ruo91:~# git clone https://github.com/ruo91/docker-kubernetes /opt/docker-kubernetes
```

#### - Build
------------
### HostOS
Kubernetes는 Docker를 사용하여 빌드하기 때문에, HostOS에서 빌드 후 tar.gz 파일을 Dockerfile이 있는 경로에 복사합니다.
(일종의 편법 입니다.)
```sh
root@ruo91:~# git clone https://github.com/GoogleCloudPlatform/kubernetes /opt/kubernetes-source
root@ruo91:~# cd /opt/kubernetes-source
root@ruo91:~# build/release.sh
root@ruo91:~# cp _output/release-tars/kubernetes-client-linux-amd64.tar.gz /opt/docker-kubernetes
root@ruo91:~# cp _output/release-tars/kubernetes-server-linux-amd64.tar.gz /opt/docker-kubernetes
```

### etcd
```sh
root@ruo91:~# cd /opt/docker-kubernetes
root@ruo91:~# docker build --rm -t kubernetes:etcd -f 00_kubernetes-etcd .
```

### Kubernetes Client
```sh
root@ruo91:~# docker build --rm -t kubernetes:client -f 01_kubernetes-client .
```

### Kubernetes Master
```sh
root@ruo91:~# docker build --rm -t kubernetes:master -f 02_kubernetes-master .
```

### Kubernetes Minion
```sh
root@ruo91:~# docker build --rm -t kubernetes:minion -f 03_kubernetes-minion .
```

#### - Run
------------
### HostOS 설정
Ubuntu 14.04 LTS 기준으로 /etc/default/docker.io 파일에 DOCKER_OPTS 변수에 소켓을 추가 후 Docker를 재시작 합니다.
(CentOS는 /etc/sysconfig/docker 파일을 수정하시면 됩니다.)

- Ubuntu
```sh
root@ruo91:~# sed -i '/^\#DOCKER_OPTS/ s:.*:DOCKER_OPTS=\"\-\-dns 8.8.8.8 \-\-dns 8.8.4.4 \-H unix\:\/\/\/var\/run\/docker.sock\":' /etc/default/docker.io
root@ruo91:~# service docker.io restart
```
- CentOS 7
```sh
root@ruo91:~# sed -i '/^OPTIONS=/ s:.*:OPTIONS=\"\-\-dns 8.8.8.8 \-\-dns 8.8.4.4 \-H unix\:\/\/\/var\/run\/docker.sock\":' /etc/sysconfig/docker
root@ruo91:~# systemctl restart docker
```

### etcd
etcd는 클러스터링 설정을 할 것 이므로 3개의 Container를 실행 합니다.
```sh
root@ruo91:~# docker run -d --name="etcd-cluster-0" -h "etcd-cluster-0" kubernetes:etcd
root@ruo91:~# docker run -d --name="etcd-cluster-1" -h "etcd-cluster-1" kubernetes:etcd
root@ruo91:~# docker run -d --name="etcd-cluster-2" -h "etcd-cluster-2" kubernetes:etcd
```

### Kubernetes Master
1개의 Container만 실행 합니다.
```sh
root@ruo91:~# docker run -d --name="kubernetes-master" -h "kubernetes-master" kubernetes:master
```

### Kubernetes Minion
Kubernetes Client의 kubectl 명령어를 통해 작업이 보내어지면 실제로 Docker images를 받아오고 Container를 실행 하는 등의 역할을 담당 하는 곳이며,
적절하게 2개의 Container를 실행 하도록 합니다. 실행시 --privileged 옵션이 활성화가 되어있어야 Container 안에서 Docker 사용이 가능 해집니다.
```sh
root@ruo91:~# docker run -d --name="kubernetes-minion-0" -h "kubernetes-minion-0" --privileged=true -v /dev:/dev kubernetes:minion
root@ruo91:~# docker run -d --name="kubernetes-minion-1" -h "kubernetes-minion-1" --privileged=true -v /dev:/dev kubernetes:minion
```

### Kubernetes Client
kubectl 명령어를 사용하기 위한 별도의 관리자 Container 이므로 1개만 실행 합니다.
```sh
root@ruo91:~# docker run -d --name="kubernetes-client" -h "kubernetes-client" kubernetes:client
```
# - Setting up
-------------
### HostOS
분산 된 Container들의 통신을 위해서는 IP 또는 hostname을 알고 있어야 합니다만,
Docker는 iptables를 사용해서 IP를 할당하는 방식이므로 고정 IP 설정이 어렵습니다.

방법이야 많겠지만, 가장 쉽게 설정 할 수 있는 방법은 Pipework를 사용하는 것입니다.
Pipework는 Container내에 존재하는 eth 인터페이스를 복제하여 사용자가 지정한 CIDR을 적용하는 방식입니다.

따라서, Pipework를 설치 후 진행 하도록 하겠습니다.
```sh
root@ruo91:~# curl -o /usr/bin/docker-pipework \
-L "https://raw.githubusercontent.com/jpetazzo/pipework/master/pipework" && \
chmod a+x /usr/bin/docker-pipework
```

그리고, 설정할 Container의 IP 정보는 아래와 같습니다.
```sh
Hostname                  CIDR
etcd-cluster-0        172.17.1.1/16
etcd-cluster-1        172.17.1.2/16
etcd-cluster-2        172.17.1.3/16
kubernetes-master     172.17.1.4/16
kubernetes-minion-0   172.17.1.5/16
kubernetes-minion-1   172.17.1.6/16
kubernetes-client     172.17.1.7/16
```

### etcd
etcd는 클러스터링 설정을 해야 하므로 각각의 Container들의 고정 IP주소가 필요 합니다.

pipework를 통해 고정 IP로 지정 합니다.
```sh
root@ruo91:~# docker-pipework docker0 etcd-cluster-0 172.17.1.1/16
root@ruo91:~# docker-pipework docker0 etcd-cluster-1 172.17.1.2/16
root@ruo91:~# docker-pipework docker0 etcd-cluster-2 172.17.1.3/16
```

이후 etcd를 실행하여 클러스터로 묶습니다.
(SSH password: kubernetes)

- 사용법
```sh
root@ruo91:~# ssh 172.17.1.1 "etcd-cluster -h"
Usage: /bin/etcd-cluster [Options] [Arguments]

- Options
e, etcd         : etcd
k, kill         : kill of process

- Arguments
s, start        : Start commands
m, manual       : Manual commands
e, etcd         : kill of apiserver (k or kill option only.)
                ex) /bin/etcd-cluster k e or /bin/etcd-cluster kill etcd
```
- etcd-cluster-0
```sh
root@ruo91:~# ssh 172.17.1.1 "etcd-cluster etcd start"
Start ETCD...
done
```

- etcd-cluster-1
```sh
root@ruo91:~# ssh 172.17.1.2 "etcd-cluster etcd start"
Start ETCD...
done
```

- etcd-cluster-2
```sh
root@ruo91:~# ssh 172.17.1.3 "etcd-cluster etcd start"
Start ETCD...
done
```

### Kubernetes Master
Master 서버에는 kube-api-server, kube-scheduler, kube-controller-manager 명령어를 통해 서버를 실행 합니다.

실행하기 전에 pipework를 통해 고정 IP로 지정 합니다.
```sh
root@ruo91:~# docker-pipework docker0 kubernetes-master 172.17.1.4/16
```

이제 api-server, scheduler, controller-manager를 실행 하겠습니다.

- 사용법
```sh
root@ruo91:~# ssh 172.17.1.4 "k8s -h"
Usage: /bin/k8s [Options] [Arguments]

- Options
a, api          : apiserver
s, sd           : scheduler
c, cm           : controller manager
k, kill         : kill of process

- Arguments
s, start        : Start commands
m, manual       : Manual commands

all             : kill of all server (k or kill option only.)
                ex) /bin/k8s k all or /bin/k8s kill all

a, api          : kill of apiserver (k or kill option only.)
                ex) /bin/k8s k a or /bin/k8s kill api

s, sd           : kill of scheduler (k or kill option only.)
                ex) /bin/k8s k s or /bin/k8s kill sd

c, cm           : kill of controller manager (k or kill option only)
                ex) /bin/k8s k c or /bin/k8s kill cm
```

- api-server
```sh
root@ruo91:~# ssh 172.17.1.4 "k8s api start"
Start API Server...
done
```

- scheduler
```sh
root@ruo91:~# ssh 172.17.1.4 "k8s sd start"
Start Scheduler...
done
```

- controller-manager
```sh
root@ruo91:~# ssh 172.17.1.4 "k8s cm start"
Start Controller Manager...
done
```

### Kubernetes Minion
Minion 같은 경우에는 Container안에서 Docker를 사용할 수 있도록 만들어 졌습니다.
이것은 실제 물리 서버에서 구성한 것과 같이 Docker images를 받아오고 Container를 실행 할 수 있도록 하기 위함입니다.

Minion도 역시 pipework를 통해 고정 IP를 설정 합니다.
```sh
root@ruo91:~# docker-pipework docker0 kubernetes-minion-0 172.17.1.5/16
root@ruo91:~# docker-pipework docker0 kubernetes-minion-1 172.17.1.6/16
```

Conatiner들의 RR(Round Robin)을 담당하는 kube-proxy와 Minion을 제어하는 agent인 kubelet 명령어를 통해 실행 할 것입니다.

- 사용법
```sh
root@ruo91:~# ssh 172.17.1.5 "minion -h"
Usage: /bin/minion [Options] [Arguments]

- Options
p, proxy        : proxy
kb, kubelet     : kubelet
k, kill         : kill of process

- Arguments
s, start        : Start commands
m, manual       : Manual commands

all             : kill of all server (k or kill option only.)
                ex) /bin/minion k all or /bin/minion kill all

p, proxy        : kill of apiserver (k or kill option only.)
                ex) /bin/minion k p or /bin/minion kill proxy

kb, kubelet     : kill of scheduler (k or kill option only.)
                ex) /bin/minion k kb or /bin/minion kill kubelet
```

- kube-proxy
```sh
root@ruo91:~# ssh 172.17.1.5 "minion proxy start"
Start Proxy...
done
```

- kubelet
```sh
root@ruo91:~# ssh 172.17.1.5 "minion kubelet start"
Start Kubelet...
done
```
# - Test
--------
이제 테스트를 위해 kubernetes-client 서버에 접속 해볼 것입니다.
```sh
root@ruo91:~# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' kubernetes-client`
```

Container의 이름은 nginx, Label은 production, Docker images는 ruo91 사용자의 nginx 이미지, 실행 갯수는 20개, Master 서버의 API Server 정보를 입력 하여 실행 해봅니다.
```
root@kubernetes-client:~# kubectl run-container nginx -l name=production --image=ruo91/nginx --replicas=20 -s 172.17.1.87:8080
```
```
CONTROLLER   CONTAINER(S)   IMAGE(S)      SELECTOR          REPLICAS
nginx        nginx          ruo91/nginx   name=production   20
```

이제 Pods의 정보를 확인 해보면 아직까지는 Pending으로 되어 있습니다.
```
root@kubernetes-client:~# kubectl get pods -s 172.17.1.87:8080
POD           IP        CONTAINER(S)   IMAGE(S)      HOST                   LABELS            STATUS    CREATED
nginx-06cgi             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-1todg             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-2t3cn             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-7gfle             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-b6cp5             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-i59dr             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-ibund             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-j6d0j             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-lanfl             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-nahv4             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-nyapo             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-o1huh             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-qt0et             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-ugspl             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-w51jp             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-xa34j             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-y3jg3             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-ysuhv             nginx          ruo91/nginx   kubernetes-minion-1/   name=production   Pending   20 seconds
nginx-yu4n4             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
nginx-zzo1k             nginx          ruo91/nginx   kubernetes-minion-0/   name=production   Pending   20 seconds
```
시간이 지나면 다음과 같이 Running으로 바뀌게 됩니다.
```
root@kubernetes-client:~# kubectl get pods -s 172.17.1.87:8080
```
```
POD           IP          CONTAINER(S)   IMAGE(S)      HOST                              LABELS            STATUS    CREATED
nginx-06cgi   10.0.0.8    nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-1todg   10.0.0.10   nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-2t3cn   10.0.0.4    nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-7gfle   10.0.0.11   nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-b6cp5   10.0.0.6    nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-i59dr   10.0.0.3    nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-ibund   10.0.0.2    nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-j6d0j   10.0.0.7    nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-lanfl   10.0.0.4    nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-nahv4   10.0.0.9    nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-nyapo   10.0.0.7    nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-o1huh   10.0.0.3    nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-qt0et   10.0.0.5    nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-ugspl   10.0.0.5    nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-w51jp   10.0.0.10   nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-xa34j   10.0.0.8    nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-y3jg3   10.0.0.6    nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-ysuhv   10.0.0.9    nginx          ruo91/nginx   kubernetes-minion-1/172.17.1.89   name=production   Running   11 minutes
nginx-yu4n4   10.0.0.11   nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
nginx-zzo1k   10.0.0.2    nginx          ruo91/nginx   kubernetes-minion-0/172.17.1.88   name=production   Running   11 minutes
```

# - Kubernetes Web UI
----------------------
Kubernetes의 API 서버는 기본적으로 8080 포트를 통해 Web UI를 지원하므로, HostOS에 Nginx 같은 웹서버를 사용한다면,
Reverse Proxy 설정을 통하여 넘겨주면 쉽게 접속이 가능합니다.
```
# Kubernetes web ui
server {
	listen  80;
	server_name kubernetes.yongbok.net;

	location / {
		proxy_set_header Host $host;
		proxy_set_header X-Forwarded-Host $host;
		proxy_set_header X-Forwarded-Server $host;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_pass http://172.17.1.4:8080;
		client_max_body_size 10M;
	}
}
```

Kubernetes Client & Master
----------------------
![Kubernetes Client and Master][1]

Kubernetes Client
----------------------
![Kubernetes Client][2]

Kubernetes Web UI
-----------------------------
![Kubernetes Web UI][3]

Kubernetes Web UI - Pods
----------------
![Kubernetes Web UI][4]

Kubernetes Web UI - API
----------------
![Kubernetes Web UI][5]

Thanks. :-)
[0]: http://cdn.yongbok.net/ruo91/img/kubernetes/The_architecture_diagram_of_docker_kubernetes.png
[1]: http://cdn.yongbok.net/ruo91/img/kubernetes/docker-kubernetes-0.png
[2]: http://cdn.yongbok.net/ruo91/img/kubernetes/docker-kubernetes-1.png
[3]: http://cdn.yongbok.net/ruo91/img/kubernetes/docker-kubernetes-web-ui-0.png
[4]: http://cdn.yongbok.net/ruo91/img/kubernetes/docker-kubernetes-web-ui-1.png
[5]: http://cdn.yongbok.net/ruo91/img/kubernetes/docker-kubernetes-web-ui-2.png
