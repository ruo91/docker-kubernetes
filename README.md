Dockerfile - Google Kubernetes (test only)
=====================================
![0]

# - About Kubernetes?
------------------
Google의 Container 관리 도구인 Kubernetes를 Docker를 사용해서, 물리 서버 1대 만으로도 테스트를 해볼 수 있도록 만들어 봤습니다.
Kubernetes의 대해서는 아래 주소를 또는 구글을 통해 참고 하시기 바랍니다.

link: http://www.yongbok.net/blog/google-kubernetes-container-cluster-manager/

#### - Clone
------------
Github 저장소에서 Dockerfile을 받아 옵니다.
```
root@ruo91:~# git clone https://github.com/ruo91/docker-kubernetes /opt/docker-kubernetes
```

#### - Build
------------
### HostOS
Kubernetes는 Docker를 사용하여 빌드하기 때문에, HostOS에서 빌드 후 tar.gz 파일을 Dockerfile이 있는 경로에 복사합니다.
(일종의 편법 입니다.)
```
root@ruo91:~# git clone https://github.com/GoogleCloudPlatform/kubernetes /opt/kubernetes-source
root@ruo91:~# cd /opt/kubernetes-source
root@ruo91:~# build/release.sh
root@ruo91:~# cp _output/release-tars/kubernetes-client-linux-amd64.tar.gz /opt/docker-kubernetes
root@ruo91:~# cp _output/release-tars/kubernetes-server-linux-amd64.tar.gz /opt/docker-kubernetes
```

### etcd
```
root@ruo91:~# cd /opt/docker-kubernetes
root@ruo91:~# docker build --rm -t kubernetes:etcd -f 00_kubernetes-etcd .
```

### Kubernetes Client
```
root@ruo91:~# docker build --rm -t kubernetes:client -f 01_kubernetes-client .
```

### Kubernetes Master
```
root@ruo91:~# docker build --rm -t kubernetes:master -f 02_kubernetes-master .
```

### Kubernetes Minion
```
root@ruo91:~# docker build --rm -t kubernetes:minion -f 03_kubernetes-minion .
```

#### - Run
------------
### etcd
etcd는 클러스터링 설정을 할 것 이므로 3개의 Container를 실행 합니다.
```
root@ruo91:~# docker run -d --name="etcd-cluster-0" -h "etcd-cluster-0" kubernetes:etcd
root@ruo91:~# docker run -d --name="etcd-cluster-1" -h "etcd-cluster-1" kubernetes:etcd
root@ruo91:~# docker run -d --name="etcd-cluster-2" -h "etcd-cluster-2" kubernetes:etcd
```

### Kubernetes Client
kubectl 명령어를 사용하기 위한 별도의 관리자 Container 이므로 1개만 실행 합니다.
```
root@ruo91:~# docker run -d --name="kubernetes-client" -h "kubernetes-client" kubernetes:client

```

### Kubernetes Master
1개의 Container만 실행 합니다.
```
root@ruo91:~# docker run -d --name="kubernetes-master" -h "kubernetes-master" kubernetes:master
```

### Kubernetes Minion
Kubernetes Client의 kubectl 명령어를 통해 작업이 보내어지면 실제로 Docker images를 받아오고 Container를 실행 하는 등의 역할을 담당 하는 곳이며,
적절하게 2개의 Container를 실행 하도록 합니다. 실행시 --privileged 옵션이 활성화가 되어있어야 Container 안에서 Docker 사용이 가능 해집니다.
```
root@ruo91:~# docker run -d --name="kubernetes-minion-0" -h "kubernetes-minion-0" --privileged=true kubernetes:minion
root@ruo91:~# docker run -d --name="kubernetes-minion-1" -h "kubernetes-minion-1" --privileged=true kubernetes:minion
```

# - Setting up
-------------
### etcd
etcd는 클러스터링 설정을 해야 하므로 각각의 Container들의 IP주소가 필요 합니다.
Dockerfile을 보시면 아시겠지만, /etc/hosts 에 등록 된 hostname을 사용 하도록 만들어 두었기 때문에, hostname 설정만 하시면 됩니다.
```
root@ruo91:~# docker inspect -f '{{ .NetworkSettings.IPAddress }}' \
etcd-cluster-0 etcd-cluster-1 etcd-cluster-2
```
```
172.17.1.83
172.17.1.84
172.17.1.85
```

SSH로 접속하여 etcd의 IP 주소를 각각의 Container에 추가 하며, 비밀번호는 kubernetes이고,
etcd를 실행 하는데, 미리 만들어둔 "/opt/etcd-cluster.sh" 쉘 스크립트를 실행 합니다.
```
root@ruo91:~# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' etcd-cluster-0` \
"echo '172.17.1.84 etcd-cluster-1' >> /etc/hosts &&
 echo '172.17.1.85 etcd-cluster-2' >> /etc/hosts &&
 /opt/etcd-cluster.sh > /tmp/etcd-cluster-0.log 2>&1 &"
```

etcd-cluster-0을 제외한 etcd-cluster-1, etcd-cluster-2는 etcd의 cluster name을 따로 변경 해주고 실행 합니다.
```
root@ruo91:~# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' etcd-cluster-1` \
"echo '172.17.1.83 etcd-cluster-1' >> /etc/hosts &&
 echo '172.17.1.85 etcd-cluster-2' >> /etc/hosts &&
 sed -i 's/\-\-name \$ETCD_CLUSTER_NAME_0/\-\-name \$ETCD_CLUSTER_NAME_1/g' /opt/etcd-cluster.sh &&
 /opt/etcd-cluster.sh > /tmp/etcd-cluster-1.log 2>&1 &"
```
```
root@ruo91:~# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' etcd-cluster-2` \
"echo '172.17.1.83 etcd-cluster-1' >> /etc/hosts &&
 echo '172.17.1.84 etcd-cluster-2' >> /etc/hosts &&
 sed -i 's/\-\-name \$ETCD_CLUSTER_NAME_0/\-\-name \$ETCD_CLUSTER_NAME_2/g' /opt/etcd-cluster.sh &&
 /opt/etcd-cluster.sh > /tmp/etcd-cluster-0.log 2>&1 &"
```

### Kubernetes Master
Master 서버에는 kube-api-server, kube-scheduler, kube-controller-manager 명령어를 통해 서버를 실행 하는데,
api-server는 etcd에 정보를 저장하기 때문에 etcd 클러스터의 IP를 요구하고,
kube-controller-manager는 machines 이라는 옵션을 통해 Minion들의 IP를 요구 하므로, 관련 IP를 /etc/hosts 파일에 추가 합니다.
```
root@ruo91:~# docker inspect -f '{{ .NetworkSettings.IPAddress }}' \
etcd-cluster-0 etcd-cluster-1 etcd-cluster-2 kubernetes-minion-0 kubernetes-minion-1
```
```
172.17.1.83
172.17.1.84
172.17.1.85
172.17.1.88
172.17.1.89
```
api-server, scheduler, controller-manager를 실행 해볼것인데, 미리 만들어진 "/opt/api-server.sh", "/opt/scheduler.sh", "/opt/controller-manager.sh" 쉘 스크립트 순으로 실행 합니다.
```
root@ruo91:~# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' kubernetes-master` \
"echo '172.17.1.83 etcd-cluster-0' >> /etc/hosts &&
 echo '172.17.1.84 etcd-cluster-1' >> /etc/hosts &&
 echo '172.17.1.85 etcd-cluster-2' >> /etc/hosts &&
 echo '172.17.1.88 kubernetes-minion-0' >> /etc/hosts &&
 echo '172.17.1.89 kubernetes-minion-1' >> /etc/hosts &&
 /opt/api-server.sh > /tmp/api-server.log 2>&1 & &&
 /opt/scheduler.sh > /tmp/scheduler.log 2>&1 & &&
 /opt/controller-manager.sh > /tmp/controller-manager.log 2>&1 &"
```

### Kubernetes Minion
Minion 같은 경우에는 Container안에서 Docker를 사용할 수 있도록 만들어 졌습니다.
이것은 실제 물리 서버에서 구성한 것과 같이 Docker images를 받아오고 Container를 실행 할 수 있도록 하기 위함입니다.

Minion도 역시 실행할때 Master의 API Server를 통해 정보를 받아 오므로 Master의 hostname을 추가 해야 합니다.
```
root@ruo91:~# docker inspect -f '{{ .NetworkSettings.IPAddress }}' kubernetes-master
```
```
172.17.1.87
```

Conatiner들의 RR(Round Robin)을 담당하는 kube-proxy와 Minion을 제어하는 agent인 kubelet 명령어를 통해 실행 할 것인데,
미리 만들어진 "/opt/proxy.sh", "/opt/kubelet.sh" 쉘 스크립트를 통해 실행 합니다.
```
root@ruo91:~# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' kubernetes-minion-0` \
"echo '172.17.1.87 kubernetes-master' >> /etc/hosts &&
 /opt/proxy.sh > /tmp/proxy.log 2>&1 & &&
 /opt/kubelet.sh > /tmp/kubelet.log 2>&1 &"
```
```
root@ruo91:~# ssh `docker inspect -f '{{ .NetworkSettings.IPAddress }}' kubernetes-minion-1` \
"echo '172.17.1.87 kubernetes-master' >> /etc/hosts &&
 /opt/proxy.sh > /tmp/proxy.log 2>&1 & &&
 /opt/kubelet.sh > /tmp/kubelet.log 2>&1 &"
```

# - Test
--------
이제 테스트를 위해 kubernetes-client 서버에 접속합니다.
```
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
		proxy_pass http://172.17.1.87:8080;
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