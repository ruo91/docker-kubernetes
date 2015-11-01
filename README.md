Dockerfile - Google Kubernetes (test only)
=====================================
![0]

# - Google Kubernetes?
-----------------------
Container를 쉽게 관리 할 수 있도록 만든 오픈소스 도구 입니다.
참고: http://www.yongbok.net/blog/google-kubernetes-container-cluster-manager/

# - Dockerfile로 만들게 된 이유가 무엇입니까?
--------------------------------------------
실제와 같은 환경을 구축 및 테스트 할때 시간 비용을 줄이고자 만들었습니다.

#### - Clone
------------
Github 저장소에서 Dockerfile을 받아 옵니다.
```sh
root@ruo91:~# git clone https://github.com/ruo91/docker-kubernetes /opt/docker-kubernetes
```

#### - Build
------------
Kubernetes는 Docker를 사용하여 빌드하기 때문에, HostOS에서 빌드 후 tar.gz 파일을 Dockerfile이 있는 경로에 복사합니다.
(일종의 편법 입니다.)
```sh
root@ruo91:~# git clone https://github.com/kubernetes/kubernetes /opt/kubernetes-source
root@ruo91:~# cd /opt/kubernetes-source
root@ruo91:~# git checkout -b release-1.1 origin/release-1.1
root@ruo91:~# make quick-release
root@ruo91:~# cp _output/release-tars/kubernetes-client-linux-amd64.tar.gz /opt/docker-kubernetes
root@ruo91:~# cp _output/release-tars/kubernetes-server-linux-amd64.tar.gz /opt/docker-kubernetes
```

이후 docker-kubernetes.sh 쉘스크립트를 통해 etcd, master, minion, client를 빌드 합니다.
```sh
root@ruo91:~# cd /opt/docker-kubernetes
root@ruo91:~# ./docker-kubernetes.sh build start
```

#### - Run
------------
etcd x3, master x1, minion x2, client x1 개의 컨테이너를 실행 합니다.
```sh
root@ruo91:~# ./docker-kubernetes.sh run yes
```

# - Test
--------
docker exec 명령어를 통해 kubernetes-client 컨테이너에서 테스트 해볼 것입니다.
(-s 옵션은 API Server의 IP와 포트를 지정 해주면 됩니다.)
```sh
root@ruo91:~# docker exec kubernetes-client kubectl get services -s 172.17.1.4:8080
docker exec kubernetes-client kubectl get services -s 172.17.1.4:8080
NAME         CLUSTER_IP   EXTERNAL_IP   PORT(S)   SELECTOR   AGE
kubernetes   10.0.0.1     <none>        443/TCP   <none>     2m
```
Minion 서버에 10개의 Nginx를 실행 해보도록 하겠습니다. 
```sh
root@ruo91:~#  docker exec kubernetes-client kubectl create -f /opt/nginx.yaml -s 172.17.1.4:8080
replicationcontroller "nginxs" created
```

create 명령어가 실행 되고 나면, 해당 Minion 서버중에 Workload가 낮은 서버에서 해당 docker 이미지를 받아오고(pending),
시간이 지나면 다음과 같이 Running 상태로 바뀌게 됩니다. 이는 곧 사용할 준비가 되었다는 뜻입니다.
(시스템 및 네트워크 상황에 따라 몇분 이상 소요 될 수 있습니다.)
```sh
root@ruo91:~# docker exec kubernetes-client kubectl get pods -s 172.17.1.4:8080
NAME           READY     STATUS    RESTARTS   AGE
nginxs-1dzwr   1/1       Running   0          1m
nginxs-2kq2o   1/1       Running   0          1m
nginxs-6ph77   1/1       Running   0          1m
nginxs-6wxx8   1/1       Running   0          1m
nginxs-98rsw   1/1       Running   0          1m
nginxs-n5gks   1/1       Running   0          1m
nginxs-odo7u   1/1       Running   0          1m
nginxs-p7oc2   1/1       Running   0          1m
nginxs-ubpyl   1/1       Running   0          1m
nginxs-utanv   1/1       Running   0          1m
```

describe 옵션으로 상태를 확인 해봅니다.
```sh
root@ruo91:~# docker exec kubernetes-client kubectl describe -f nginx.yaml -s 172.17.1.4:8080
Name:           nginxs
Namespace:      default
Image(s):       ruo91/nginx:latest
Selector:       app=nginx
Labels:         app=nginx
Replicas:       10 current / 10 desired
Pods Status:    10 Running / 0 Waiting / 0 Succeeded / 0 Failed
No volumes.
Events:
  FirstSeen     LastSeen        Count   From                            SubobjectPath   Reason                  Message
  ─────────     ────────        ─────   ────                            ─────────────   ──────                  ───────
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-n5gks
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-6wxx8
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-98rsw
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-6ph77
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-ubpyl
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-odo7u
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-1dzwr
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-utanv
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-2kq2o
  44m           44m             1       {replication-controller }                       SuccessfulCreate        Created pod: nginxs-p7oc2
```

# - Kubernetes Web UI
----------------------
Kubernetes v1.x 버전 부터는 Web UI(kube-ui)가 Minion 쪽에서 Pod로 실행 되도록 변경 되었습니다.
HostOS에 Nginx 같은 웹서버를 사용한다면, Reverse Proxy 설정을 통하여 넘겨주면 쉽게 접속이 가능합니다.
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

Kubernetes Web UI #0
---------------------
![Kubernetes Web UI #0][1]

Kubernetes Web UI #1
---------------------
![Kubernetes Web UI #1][2]

Kubernetes Web UI #2
---------------------
![Kubernetes Web UI #2][3]

Kubernetes Web UI #3
---------------------
![Kubernetes Web UI #3][4]

Kubernetes Web UI #4
---------------------
![Kubernetes Web UI #4][5]

Thanks. :-)
[0]: http://cdn.yongbok.net/ruo91/img/kubernetes/The_architecture_diagram_of_docker_kubernetes.png
[1]: http://cdn.yongbok.net/ruo91/img/kubernetes/v1.1/k8s_web_ui_0.png
[2]: http://cdn.yongbok.net/ruo91/img/kubernetes/v1.1/k8s_web_ui_1.png
[3]: http://cdn.yongbok.net/ruo91/img/kubernetes/v1.1/k8s_web_ui_2.png
[4]: http://cdn.yongbok.net/ruo91/img/kubernetes/v1.1/k8s_web_ui_3.png
[5]: http://cdn.yongbok.net/ruo91/img/kubernetes/v1.1/k8s_web_ui_4.png
