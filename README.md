# Dockerfile - Google Kubernetes (test only)
![Fig1. Kubernetes Architecture](http://cdn.yongbok.net/ruo91/architecture/k8s/kubernetes_architecture_v1.x.png)

# Google Kubernetes?
Container를 쉽게 관리 할 수 있도록 만든 오픈소스 도구 입니다.  
참고: http://www.yongbok.net/blog/google-kubernetes-container-cluster-manager/

# Dockerfile로 만들게 된 이유가 무엇입니까?
실제와 같은 환경을 구축 및 테스트 할때 시간 비용을 줄이고자 만들었습니다.

#### - Clone
Github 저장소에서 Dockerfile을 받아 옵니다.

    root@ruo91:~# git clone https://github.com/ruo91/docker-kubernetes /opt/docker-kubernetes

#### - Build
Kubernetes는 Docker를 사용하여 빌드하기 때문에, HostOS에서 빌드 후 tar.gz 파일을 Dockerfile이 있는 경로에 복사합니다.
(일종의 편법 입니다.)

    root@ruo91:~# git clone https://github.com/kubernetes/kubernetes /opt/kubernetes-source
    root@ruo91:~# cd /opt/kubernetes-source
    root@ruo91:~# make quick-release
    root@ruo91:~# cp _output/release-tars/kubernetes-client-linux-amd64.tar.gz /opt/docker-kubernetes
    root@ruo91:~# cp _output/release-tars/kubernetes-server-linux-amd64.tar.gz /opt/docker-kubernetes

이후 docker-kubernetes.sh 쉘스크립트를 통해 etcd, master, minion, client를 빌드 합니다.

    root@ruo91:~# cd /opt/docker-kubernetes
    root@ruo91:~# ./docker-kubernetes.sh build start

#### - Run
etcd x3, master x1, minion x2, client x1 개의 컨테이너를 실행 합니다.

    root@ruo91:~# ./docker-kubernetes.sh run yes

# Test
docker exec 명령어를 통해 kubernetes-client 컨테이너에서 테스트 해볼 것입니다.  
(-s 옵션은 API Server의 IP와 포트를 지정 해주면 됩니다.)

    root@ruo91:~# docker exec kubernetes-client kubectl get services -s 172.17.1.4:8080
    docker exec kubernetes-client kubectl get services -s 172.17.1.4:8080
    NAME         CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
    kubernetes   10.250.94.1     <none>        443/TCP   24m

Minion 서버에 10개의 Nginx를 실행 해보도록 하겠습니다. 

    root@ruo91:~#  docker exec kubernetes-client kubectl create -f /opt/nginx.yaml -s 172.17.1.4:8080
    replicationcontroller "nginx-svc" created

create 명령어가 실행 되고 나면, 해당 Minion 서버중에 Workload가 낮은 서버에서 해당 docker 이미지를 받아오고(pending),  
시간이 지나면 다음과 같이 Running 상태로 바뀌게 됩니다. 이는 곧 사용할 준비가 되었다는 뜻입니다.  
(시스템 및 네트워크 상황에 따라 몇분 이상 소요 될 수 있습니다.)

    root@ruo91:~# docker exec kubernetes-client kubectl get pods -s 172.17.1.4:8080
    NAME           READY     STATUS    RESTARTS   AGE
    nginxs-3a6jp   1/1       Running   0          6m
    nginxs-3x1bc   1/1       Running   0          6m
    nginxs-85aej   1/1       Running   0          6m
    nginxs-867li   1/1       Running   0          6m
    nginxs-8qa8e   1/1       Running   0          6m
    nginxs-bgt6c   1/1       Running   0          6m
    nginxs-bje1b   1/1       Running   0          6m
    nginxs-ecj4y   1/1       Running   0          6m
    nginxs-em4r7   1/1       Running   0          6m
    nginxs-eqt9v   1/1       Running   0          6m
    nginxs-fxmuf   1/1       Running   0          6m
    nginxs-mrdsm   1/1       Running   0          6m
    nginxs-oa0bt   1/1       Running   0          6m
    nginxs-onxg0   1/1       Running   0          6m
    nginxs-uxlhf   1/1       Running   0          6m
    nginxs-uy8yu   1/1       Running   0          6m
    nginxs-vrusv   1/1       Running   0          6m
    nginxs-vvjwc   1/1       Running   0          6m
    nginxs-xxd5f   1/1       Running   0          6m
    nginxs-y31ow   1/1       Running   0          6m

describe 옵션으로 상태를 확인 해봅니다.

    root@ruo91:~# docker exec kubernetes-client kubectl describe -f nginx.yaml -s 172.17.1.4:8080
    Name:                   nginx-svc
    Namespace:              default
    Labels:                 app=nginx
    Selector:               <none>
    Type:                   NodePort
    IP:                     10.250.94.161
    Port:                   http    80/TCP
    NodePort:               http    30195/TCP
    Endpoints:              <none>
    Session Affinity:       None
    No events.
    
    Name:           nginxs
    Namespace:      default
    Image(s):       ruo91/nginx:latest
    Selector:       app=nginx
    Labels:         app=nginx
    Replicas:       20 current / 20 desired
    Pods Status:    20 Running / 0 Waiting / 0 Succeeded / 0 Failed
    No volumes.
    Events:
      FirstSeen     LastSeen        Count   From                            SubobjectPath   Type            Reason                  Message
      ---------     --------        -----   ----                            -------------   --------        ------                  -------
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-fxmuf
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-uy8yu
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-8qa8e
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-867li
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-bje1b
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-xxd5f
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-onxg0
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-vvjwc
      7m            7m              1       {replication-controller }                       Normal          SuccessfulCreate        Created pod: nginxs-eqt9v
      7m            7m              11      {replication-controller }                       Normal          SuccessfulCreate        (events with common reason combined)

# Kubernetes Web UI
Kubernetes v1.x 버전 부터는 Web UI(kube-ui)가 Minion 쪽에서 Pod로 실행 되도록 변경 되었습니다.  
HostOS에 Nginx 같은 웹서버를 사용한다면, Reverse Proxy 설정을 통하여 넘겨주면 쉽게 접속이 가능합니다.

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

## Kubernetes Web UI #0
![Kubernetes Web UI #0](http://cdn.yongbok.net/ruo91/img/kubernetes/v1.2/k8s_web_ui_0.png)

## Kubernetes Web UI #1
![Kubernetes Web UI #1](http://cdn.yongbok.net/ruo91/img/kubernetes/v1.2/k8s_web_ui_1.png)

## Kubernetes Web UI #2
![Kubernetes Web UI #2](http://cdn.yongbok.net/ruo91/img/kubernetes/v1.2/k8s_web_ui_2.png)

## Kubernetes Web UI #3
![Kubernetes Web UI #3](http://cdn.yongbok.net/ruo91/img/kubernetes/v1.2/k8s_web_ui_3.png)

## Kubernetes Web UI #4
![Kubernetes Web UI #4](http://cdn.yongbok.net/ruo91/img/kubernetes/v1.2/k8s_web_ui_4.png)

## Kubernetes Web UI #5
![Kubernetes Web UI #5](http://cdn.yongbok.net/ruo91/img/kubernetes/v1.2/k8s_web_ui_5.png)

Thanks. :-)
