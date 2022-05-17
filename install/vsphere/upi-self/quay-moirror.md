Using https://github.com/quay/openshift-mirror-registry  

CentOS 8.5  
ocp image size: 약 10G 내외  
================= 준 비 ==================================================  
zeroSSL 인증서 사용  --> 사용하지 않을 경우, unrecognized authority error : 현재 self-signed certificate 관련 수정 중 (2021.12.24)  
host: registry.steve-ml.net  

/root 하위 dir: certs, secrets, quay  
directory 설명  
- certs : 인증서 디텍토리  
- secrets: secrets 디렉토리  
- quay: offline install dir, openshift-mirror-registry 설치 디렉터리.  

registry.steve-ml.net 도메인 등록 확인  
```
$ pwd
/root/secrets
$ unzip unzip registry.steve-ml.net.zip
$ ls
ca_bundle.crt  certificate.crt  private.key  registry.steve-ml.net.zip
$ cat certificate.crt ca_bundle.crt > ssl.cert
$ cp private.key ssl.key
$ ls
ca_bundle.crt  certificate.crt  private.key  registry.steve-ml.net.zip  ssl.cert  ssl.key

$ vi /etc/hosts
172.20.2.120  registry.steve-ml.net
```
- oc Download  
```
$ cd Download
$ mkdir ~/bin
$ curl -sL https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.7.33/openshift-client-linux-4.7.33.tar.gz |tar xzvf - -C ~/bin/
README.md
oc
kubectl
[root@registry Downloads]# oc version
Client Version: 4.7.33
```

1. Quay registry 설치  
```
$ ./openshift-mirror-registry install --initPassword passw0rd --quayHostname registry.steve-ml.net --sslCert ~/certs/ssl.cert --sslKey ~/certs/ssl.key --targetHostname registry.steve-ml.net -v
INFO[2021-12-24 16:58:35] Quay installed successfully, permament data are stored in /etc/quay-install
INFO[2021-12-24 16:58:35] Quay is available at https://registry.steve-ml.net:8443 with credentials (init, passw0rd)
```
2. 설치 확인  
```
podman login -u init -p passw0rd registry.steve-ml.net:8443
Login Succeeded!
```
https://registry.steve-ml.net:8443 에 접속 후, admin acount 생성 (Super user로 생성됨)  
`$ podman login -u admin -p passw0rd registry.steve-ml.net:8443`

3. local registry에 대한 pull secret 생성  
pullsecrts 파일은 모두 secrets dir에 생성  
```
$ mkdir secrets && cd secrets
[root@registry ~]# podman login -u admin -p passw0rd --authfile ~/secrets/local-pullsecret.json registry.steve-ml.net:8443
Login Succeeded!
[root@registry ~]# cat secret/local-pullsecret.json |jq  (email 추가)
{
  "auths": {
    "registry.steve-ml.net:8443": {
      "auth": "YWRtaW46cGFzc3cwcmQ=",
      "eamil": "whpark@saltware.co.kr"
    }
  }
}
```
4. RedHat OpenShift Cluster Manager에서 pull screet을 copy해서 ocp_pullsecret.json 에 저장   
```
$ vi ocp-pullsecret.txt
(CTRL+V)
$ dnf install -y jq
text file을 json file로 변환
$ cat ocp_pullsecret.txt | jq . > ocp-pullsecret.json
$ ls
local-pullsecret.json  ocp-pullsecret.json  ocp-pullsecret.txt
```  
5. jq를 사용하여 두 secret 병합(merge)  
`$ jq -c --argjson var "$(jq .auths ./local-pullsecret.json)" '.auths += $var' ./ocp-pullsecret.json |jq . > merged-pullsecret.json`  


6. OpenShift image mirroring  
```
$ cd ~  # $HOME dir 로 이동
$ mkdir mirror
$ LOCAL_SECRET_JSON='./secrets/merged-pullsecret.json'
$ PRODUCT_REPO='openshift-release-dev'
$ RELEASE_NAME="ocp-release"
$ OCP_RELEASE=4.7.33
$ ARCHITECTURE=x86_64
$ LOCAL_REGISTRY='registry.steve-ml.net:8443'
$ LOCAL_REPOSITORY='ocp4/openshift4'
```  
7. dry-run으로 결과 review
`oc adm release mirror -a ${LOCAL_SECRET_JSON} --to-dir=mirror quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} --dry-run`

### for install-config 항목  
```
$ oc adm -a ${LOCAL_SECRET_JSON} release mirror \
   --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} \
   --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
   --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE} --dry-run

To use the new mirrored repository to install, add the following section to the install-config.yaml:

imageContentSources:
- mirrors:
  - registry.steve-ml.net:8443/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.steve-ml.net:8443/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev


To use the new mirrored repository for upgrades, use the following to create an ImageContentSourcePolicy:

apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: example
spec:
  repositoryDigestMirrors:
  - mirrors:
    - registry.steve-ml.net:8443/ocp4/openshift4
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - registry.steve-ml.net:8443/ocp4/openshift4
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev

-----------------------------------------------------------------------------------------------    

stats: shared=5 unique=262 size=7.483GiB ratio=0.99

phase 0:
   openshift/release blobs=267 mounts=0 manifests=130 shared=5

info: Planning completed in 25.75s
info: Dry run complete

Success
Update image:  openshift/release:4.7.33-x86_64

To upload local images to a registry, run:

    oc image mirror --from-dir=mirror 'file://openshift/release:4.7.33-x86_64*' REGISTRY/REPOSITORY

info: Write configmap signature file mirror/config/signature-sha256-d3c0d73bd5c519f8.yaml
``` 
7. 오류 없을 경우 실행  

``` 
$ oc adm release mirror -a ${LOCAL_SECRET_JSON} --to-dir=mirror \
quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE}  \
2>&1 | tee ~/secrets/mirror-output.txt

To upload local images to a registry, run:

    oc image mirror --from-dir=mirror 'file://openshift/release:4.7.33-x86_64*' REGISTRY/REPOSITORY

Configmap signature file mirror/config/signature-sha256-d3c0d73bd5c519f8.yaml created
```  
8. image를 local quay registry로 uoload  
```
$ LOCAL_SECRET_JSON='./secrets/local-pullsecret.json'
dry-run 수행
$ oc image mirror --from-dir=mirror 'file://openshift/release:4.7.33-x86_64*' ${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} --dry-run
$ oc image mirror -a ${LOCAL_SECRET_JSON} --from-dir=mirror 'file://openshift/release:4.7.33-x86_64*'  \
${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
2>&1 | tee secrets/mirror-upload-output.txt
```

9. Imaage Catalog download  ==> 필요한 catalog만 pruning 해서 할 것. (#10)  
```
$ REG_CREDS=${XDG_RUNTIME_DIR}/containers/auth.json
$ cat $REG_CREDS # quay auth파일과 동일
```

따라서, catalog mirroring을 하기 위해서는 auth.json에 registry.redhat.io에 관련 credential을 추가해서  
사용해서 된다. 그렇지 않으면 인증에러 발생.  
여기서는 간단하게 위에서 만든 merged-pullsecret.json 사용  
```
$ nohup oc adm catalog mirror \ 
registry.redhat.io/redhat/redhat-operator-index:v4.7  \ 
file://local/index -a ~/secrets/merged-pullsecret.json \ 
2>1 >>  ~/logs/catalog-mirror-output.log &
```  
최소 4~5시간 걸리는 작업이므로 background 로 수행한다.  
mirroring location은 workding directory 아래 v2 dir.  


10. Image Catalog Upload to local mirror registry  
under V2 parent directory  
`$ oc adm catalog mirror file://local/index/redhat/redhat-operator-index:v4.7 registry.steve-ml.net:8443/olm-mirror -a ~/secretes/local-pullseret.json 2>1 > ~/logs/catalog-up-registry.log &`

3 개 파일 생성됨  
- catalogSource.yaml:  metadata.name 에 any backslash 제거할 것  
- imageContentSourcePolicy.yaml  
- mapping.txt  

11. apply catalog to cluster  
ImageContentSourcePolicy (ICSP) 생성  
`$ oc create -f <path/to/manifests/dir>/imageContentSourcePolicy.yaml`

Image Index에서 Operator Catalog를 생성하고, 이것을 OCP에 적용  
generated catalogSource.yaml 수정 또는 생성  
metadata.name 에 backslash 제거  
```
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: my-operator-catalog
  namespace: openshift-marketplace
spec:
  image: registry.steve-ml.net:8443/olm-mirror/local-index-redhat-redhat-operator-index:v4.7
  sourceType: grpc
  displayName: My Operator Catalog
```  













