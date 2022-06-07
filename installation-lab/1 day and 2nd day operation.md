**1일 차 및 2일 차 작업 수행**  
OpenShift 클러스터를 프로덕션에 공개하기 전에 기본 구성을 수행합니다.  
- kubeconfig 파일의 복사본을 저장합니다.  
- 동적 스토리지 프로바이더를 구성합니다.  
- Registry Operator를 구성하여 영구저장장치를 추가합니다.  
- 애플리케이션을 배포하여 클러스터의 기능 테스트를 수행합니다.  

1. kubeconfig file저장  
```  
[lab@utility ~]$ scp /home/lab/ocp4upi/auth/kubeconfig student@workstation:  
```  
2. 영구저장장치를 사용하여  이미지 레지스트리를 구성  
2.1 kubeconfig 파일 저장  
```  
export KUBECONFIG=~/ocp4upi/auth/kubeconfig  
```  
2.2  NFS 내보내기를 조사 (구성)  
```  
[lab@utility ~]$ cat /etc/exports
/exports *(rw,sync,no_wdelay,no_root_squash,insecure,fsid=0)

[lab@utility ~]$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
vda    252:0    0   10G  0 disk
├─vda1 252:1    0    1M  0 part
├─vda2 252:2    0  100M  0 part /boot/efi
└─vda3 252:3    0  9,9G  0 part /
vdb    252:16   0   40G  0 disk
└─vdb1 252:17   0   40G  0 part /exports

[lab@utility ~]$ df -h
Filesystem       Size   Used Avail Use% Mounted on
...output omitted...
/dev/vdb1         40G   318M   40G   1% /exports
/dev/vda2        100M   6,8M   94M   7% /boot/efi
tmpfs            183M      0  183M   0% /run/user/1000
```  
/exports NFS 내보내기에 약 40GB의 디스크 공간을 사용할 수 있습니다.  

PV에서 사용할  /exports/registry 생성  
```  
mkdir /exports/registry
sudo chmod 777 /exports/registry/
```  

2.3 pv.yaml 및 pv.yaml 생성 및 적용 ( under yaml dir )  
```  
oc create -f pv.yaml
oc create -f pvc.yaml
```  
2.4 spec 섹션에서 Image Registry Operator를 "Managed" 상태로 설정합니다. 클러스터 이미지 레지스트리의 구성을 편집하여 PVC를 추가합니다. 또한 포드 복제본 두 개가(worker node 2개) 있도록 이미지 레지스트리를 구성합니다.  
```  
[lab@utility ~]$ oc edit configs.imageregistry/cluster
...output omitted...
spec:
...output omitted...
  managementState: Managed
...output omitted...
  proxy: {}
  replicas: 2
  requests:
...output omitted...
  rolloutStrategy: RollingUpdate
  storage:
    pvc:
      claim: registry-claim
...output omitted...
```  

2.5 상태 확인
```  
oc get pv -A  
oc get pvc -A
oc get clusteroperator
```  
2.6 openshift-image-registry 네임스페이스에서 레지스트리 포드 수를 확인  
```  
oc get pods -n openshift-image-registry -o wide  
```  

3. 동적 스토리지 프로비전 프로그램을 구성  
**주의**  
**nfs-subdir-external-provisioner는 Red Hat에서 지원하지 않으며 프로덕션 환경에서 사용하지 않는 것이 좋습니다.**  
3.1  kubernetes-sigs/nfs-subdir-external-provisioner GitHub 리포지토리를 복제  
```  
git clone https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/
```  



4. 클러스터 기능 테스트를 수행
4.1 etherpad라는 새 프로젝트를 생성하고 작업 프로젝트로 설정합니다.
```  
oc new-project etherpad  
mkdir etherpad
cd etherpad
cat <<EOF >> etherpad-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: etherpad
  labels:
    app.kubernetes.io/name: etherpad
    app.kubernetes.io/version: "latest"
spec:
  type: ClusterIP
  ports:
    - port: 9001
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app.kubernetes.io/name: etherpad
EOF

cat <<EOF >> etherpad-route.yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  annotations:
    openshift.io/host.generated: "true"
  name: etherpad
  labels:
    app.kubernetes.io/name: etherpad
    app.kubernetes.io/version: "latest"
spec:
  host:
  port:
    targetPort: http
  to:
    kind: Service
    name: etherpad
    weight: 100
  tls:
    insecureEdgeTerminationPolicy: Redirect
    termination: edge
EOF

cat <<EOF >> etherpad-pvc.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: etherpad
  labels:
    app.kubernetes.io/name: etherpad
    app.kubernetes.io/version: "latest"
spec:
  accessModes:
    - "ReadWriteOnce"
  resources:
    requests:
      storage: "1Gi"
EOF

cat <<EOF >>  etherpad-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: etherpad
  labels:
    app.kubernetes.io/name: etherpad
    app.kubernetes.io/version: "latest"
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: etherpad
  template:
    metadata:
      labels:
        app.kubernetes.io/name: etherpad
    spec:
      securityContext:
        {}
      containers:
        - env:
          - name: TITLE
            value: DO322 Etherpad
          - name: DEFAULT_PAD_TEXT
            value: Etherpad for sharing ideas between the students.
          name: etherpad
          securityContext:
            {}
          image: "quay.io/redhattraining/etherpad:latest"
          imagePullPolicy: IfNotPresent
          ports:
            - name: http
              containerPort: 9001
              protocol: TCP
          livenessProbe:
            httpGet:
              path: /
              port: http
          readinessProbe:
            httpGet:
              path: /
              port: http
          resources:
            {}
          volumeMounts:
            - name: etherpad-data
              mountPath: /opt/etherpad-lite/var
      volumes:
      - name: etherpad-data
        persistentVolumeClaim:
          claimName: etherpad
EOF  
```  

```  
oc create -f etherpad-pvc.yaml
oc create -f etherpad-svc.yaml
oc create -f etherpad-route.yaml
oc create -f etherpad-deployment.yaml

oc get all
oc get events -o template --template  '{{range .items}}{{.message}}{{"\n"}}{{end}}'
```  

  


















