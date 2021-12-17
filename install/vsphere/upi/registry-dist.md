on Fedora 35. hostname: dist.steve-ml.net
(참조: https://developer.ibm.com/tutorials/red-hat-openshift-restricted-network-disconnected-installation-on-ibm-z/ )

### 1. Install a private image registry
1. (Optional: Proxy 사용시) Here are the export proxy variables that will be used by Podman and later by oc commands
$ export HTTP_PROXY=http://my-proxy.example.com:9090
$ export HTTPS_PROXY=http://my-proxy.example.com:9090
$ export NO_PROXY=.internal.example.com,.example.com

2. docker-distribution 설치 (install registry)
$ dnf install -y docker-distribution

3. Create the folders that will be used by the registry and the self-signed certificate
$ mkdir -p /etc/docker-distribution/certs
$ cd /etc/docker-distribution/certs
인증 config 파일 작성
$ vi csr_answer.txt
----------------------------
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
C = KR
ST = Seoul
L = Gurogu
O = Saltware
OU = OSS
emailAddress = webmaster@steve-ml.net
CN = dist.steve-ml.net
-----------------------------------

$ openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -config csr_answer.txt

위 정보 이상 (ext v3)를 넣으면 unknown authority 에러 발생

4. image registry에서 사용할 folder 생성
$ mkdir -p /var/registry/docker-distribution

5. basic htpasswd 인증파일 생성
$ dnf install -y httpd-tools
$ htpasswd -bBc /etc/docker-distribution/registry_passwd admin passw0rd

6. registry config 파일 생성
(참조: https://docs.docker.com/registry/configuration/ )
$ vi /etc/docker-distribution/registry/config.yml
--------------------------------------------------------------
version: 0.1
log:
    fields:
        service: registry
storage:
    cache:
        layerinfo: inmemory
    filesystem:
        rootdirectory: /var/registry/docker-distribution
    delete:
        enabled: true
http:
    addr: :5000
    host: https://dist.steve-ml.net:5000
    tls:
        certificate: /etc/docker-distribution/certs/domain.crt
        key: /etc/docker-distribution/certs/domain.key
    secret: testsecretrandom
    relativeurls: false
auth:
    htpasswd:
        realm: basic-realm
        path: /etc/docker-distribution/registry_passwd
---------------------------------------------------------------------

7. service 및 확인
$ systemctl enable docker-distribution
$ systemctl start docker-distribution
$ systemctl status docker-distribution

$ curl -u admin:passw0rd -k https://localhost:5000/v2/_catalog
{"repositories":[]}

$ dnf install -y podman

8. Trust the repository (cert 재생성시: reset trusted CA certs: https://access.redhat.com/solutions/1549003 )
$ cp /etc/docker-distribution/certs/domain.crt /etc/pki/ca-trust/source/anchors/
$ update-ca-trust

9. podman login
$ export GODEBUG=x509ignoreCN=0
$ podman login -u admin -p passw0rd dist.steve-ml.net:5000
Login Succeeded!

__10. sample image test__
먼저 registry.redhat.io login
$ podman login registry.redhat.io
Username: whpark
Password:
Login Succeeded!

$ podman pull ubi8
$ podman images
REPOSITORY                       TAG         IMAGE ID      CREATED      SIZE
registry.access.redhat.com/ubi8  latest      cc0656847854  6 weeks ago  235 MB
$ podman tag registry.access.redhat.com/ubi8:latest dist.steve-ml.net:5000/ubi8
$ podman images | grep ubi8
registry.access.redhat.com/ubi8  latest      cc0656847854  6 weeks ago  235 MB
dist.steve-ml.net:5000/ubi8      latest      cc0656847854  6 weeks ago  235 MB
$ podman push dist.steve-ml.net:5000/ubi8
Getting image source signatures
Checking if image destination supports signatures
Error: Copying this image requires changing layer representation, 
which is not possible (image is signed or the destination specifies a digest)

$ podman push dist.steve-ml.net:5000/ubi8 --remove-signatures
Copying blob 0488bd866f64 done
Copying blob 0d3f22d60daf done
Copying config cc06568478 done
Writing manifest to image destination
Storing signatures

$ curl -u admin:passw0rd -k https://dist.steve-ml.net:5000/v2/_catalog
{"repositories":["ubi8"]}

11. firewall port 설정
$ firewall-cmd --set-default-zone=public
$ firewall-cmd --get-default-zone
public
$ firewall-cmd --list-ports

$ firewall-cmd --add-port=5000/tcp --permanent
$ firewall-cmd --reload
$ firewall-cmd --list-ports
5000/tcp

### 2. Merge the pull secrets
home directory로 변경
$ cd
1. local registry에 대한 pull secret 생성
$ podman login -u admin -p passw0rd --authfile ./local_pullsecret.json dist.steve-ml.net:5000
Login Succeeded!

2. cat local_pullsecret.json;echo
{
        "auths": {
                "dist.steve-ml.net:5000": {
                        "auth": "YWRtaW46cGFzc3cwcmQ="
                }
        }
}

3. RedHat OpenShift Cluster Manager에서 pull screet을 copy해서 ocp_pullsecret.json 에 저장
$ vi ocp_pullsecret.json
(CTRL+V)

4. jq를 사용하여 두 secret 병합(merge)
$ dnf install -y jq
$ jq -c --argjson var "$(jq .auths ./local_pullsecret.json)" '.auths += $var' ./ocp_pullsecret.json > merged_pullsecret.json

### 3. Mirror the Content

1. 환경변수 설정
merged pull secret copy
$ cd ~
$ mkdir -p /var/registry/oc4.7/secrets
$ cp ./merged_pullsecret.json /var/registry/oc4.7/secrets/

$ vi ocp_env
export OCP_RELEASE=4.7.33
export LOCAL_REGISTRY=dist.steve-ml.net:5000
export LOCAL_REPOSITORY=ocp4/openshift4
export PRODUCT_REPO=openshift-release-dev 
export LOCAL_SECRET_JSON=/var/registry/oc4.7/secrets/merged_pullsecret.json 
export RELEASE_NAME=ocp-release 
export ARCHITECTURE=x86_64
$ source ocp_env
$ echo $ARCHITECTURE
x86_64

2. 실제 수행 전 dry run으로 실행하여 검증
openshit client download
$ mkdir bin
$ echo 'export PATH=$PATH:$HOME/bin' >> .bash_profile
$ source .bash_profile

$ mkdir download
$ wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.7.33/openshift-client-linux-4.7.33.tar.gz -O download/oc-4.7.33.tar.gz
$ tar -xzvf download/oc-
$ tar xzvf download/oc-4.7.33.tar.gz -C ~/bin
$ oc version
Client Version: 4.7.33

$ oc adm release mirror -a ${LOCAL_SECRET_JSON}      --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE}     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE} --dry-run

실제 수행 log file은 현재 디렉터리의 mirror-output.log
$ oc adm release mirror -a ${LOCAL_SECRET_JSON}      --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE}     --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}     --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE} 2>&1 | tee -a mirror-output.log

Repository 검증
$ curl -u admin:passw0rd -k https://dist.steve-ml.net:5000/v2/_catalog

$ podman pull --authfile ~/local_pullsecret.json dist.steve-ml.net:5000/ocp4/openshift4:4.7.33-operator-lifecycle-manager





