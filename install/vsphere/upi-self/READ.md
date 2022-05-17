### 별도의 private network을 구성하지 않고, 회사 Network을 이용해서 cluster 구성  

Base Domain: steve-ml.net   
cluster name: ocp4  

구성 순서  
1. DNS: AWS Route53 domain: steve-ml.net  
2. Load Balancer 구성 ( CentOS 8)  
  - ip: 172.20.2.228,   
  - host name: lb.ocp4  
  - software: HAproxy  
    향후  HA로 구성할 경우, 228. 229 사용  
3. DHCP 구성  
회사 DHCP를 수정할 수 없으므로, RHCOS OVA의 vm template을 static ip 사용  
node-map-ip.md 참조  

4. Bastion 구성 (CentOS 8)  
vCenter domain은 내부 DNS를 사용하므로, dns는 172.20.2.230을 사용한다.  
나중에 domain을 동잏하게 하기 위해 vCenter 설치 시 vcsa.steve-ml.net로 변경할 것 (AWS Route53 사용가능 시)  
230번의 named 구성 참고.  

  aws Route53에 등록된 record nslookup 확인  
  ```
  [root@bastion ~]# nslookup api.ocp4.steve-ml.net
  Server:         172.20.2.230
  Address:        172.20.2.230#53

  Non-authoritative answer:
  Name:   api.ocp4.steve-ml.net
  Address: 172.20.2.228
  ```
  4.1 SSH Private Key 생성 및 SSH-Agent에 추가   
    4.1.1 private key 생성   
 
    (passphrase: just Enter)    
    Generating public/private rsa key pair.  
    Enter file in which to save the key (/root/.ssh/id_rsa):  
    Created directory '/root/.ssh'.  
    Enter passphrase (empty for no passphrase):  
    Enter same passphrase again:  
    Your identification has been saved in /root/.ssh/id_rsa.  
    Your public key has been saved in /root/.ssh/id_rsa.pub.  
 
4.1.2 ssh-agent를 background로 수행  
```
$ eval "$(ssh-agent -s)"
Agent pid 2509
```
4.1.3 Add your SSH private key to the ssh-agen  
```
$ ssh-add
Identity added: /root/.ssh/id_rsa (root@bastion.ocp4.steve-ml.net)
```
4.2 Install program download  
CentOS 8의 Home directory bin directory (\$HOME/bin)가 기본 path로 잡혀있다.  
bin 디렉토리를 만들고, 여기에 install program을 move한다.  
`$ mkdir ~/bin`

download할 version: 4.7.33  
```
$ cd Download
$ echo OCP_BASEURL= https://mirror.openshift.com/pub/openshift-v4/clients/ocp
$ curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.7.33/openshift-client-linux-4.7.33.tar.gz |tar xzvf - -C ~/bin oc kubectl
$ oc version
Client Version: 4.7.33
```  
4.3 Manually create install-config.yaml file  
4.3.1 create installation config dir  
`$ mkdir ocp4`  
4.3.2 install-config.yaml file 생성  
`$ vi install-config.yaml`
```
apiVersion: v1
baseDomain: steve-ml.net 
compute:
- hyperthreading: Enabled   
  name: worker
  replicas: 0 
controlPlane:
  hyperthreading: Enabled   
  name: master
  replicas: 3 
metadata:
  name: ocp4 
platform:
  vsphere:
    vcenter: vcsa.saltware.lab 
    username: username 
    password: password 
    datacenter: Datacenter 
    defaultDatastore: datastore1 
    folder: "/Datacenter/vm/ocp4" 
fips: false 
```  

위 항목 중 datacenter, defaultDatastore, folder는 govc를 통해 정보를 얻거나 생성한다. (vSphere Client 사용 가능)
govc는 govc-tip을 참고할 것

$ govc folder.create $dc/vm/ocp4

  ### Add the registry pull-secret
    your pullSecret should now be your pull secret file of your internal registry only.  
    ```
    $ REG_SECRET=`echo -n 'admin:passw0rd' | base64 -w0`
    $ echo -n "pullSecret: '" >> install-config.yaml && echo '{ "auths": {}}' | jq '.auths += {"registry.setve-ml.net:8443": {"auth": "REG_SECRET","email": "whpark@saltware.co.kr"}}' | sed "s/REG_SECRET/$REG_SECRET/" | jq -c . | sed "s/$/\'/g" >> install-config.yaml
    ```
### Attach the ssh key
`$ echo -n "sshKey: '" >> install-config.yaml && cat ~/.ssh/id_rsa.pub | sed "s/$/\'/g" >> install-config.yaml`   
   

위 install-config 파일에 mirror registry에 관련된 additionalTrustBundle  및 imageContentSources를 추가한다.  
quay-mirror 설치 참고 ( https://github.com/quay/openshift-mirror-registry )  

### Adding the Registry CA  
quay mirror registry에 사용된 ca 인증서 즉. ZeroSSL의 ca_bundle.crt 사용  
When we update the custom CA , we need to make sure we are using the right indentation which means 5 spaces from the left.  

- additionalTrustBundle 항목 추가  
```
$ echo "additionalTrustBundle: |" >> install-config.yaml
$ cat ca_bundle.crt | sed 's/^/\ \ \ \ \ /g' >> install-config.yaml
```
### ● Adding the "imageContentSources" extentsion  
```
$ cat ${REGISTRY_BASE}/downloads/secrets/mirror-output.txt | grep -A7 imageContentSources >> install-config.yaml 

imageContentSources:
- mirrors:
  - registry.steve-ml.net:8443/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.steve-ml.net:8443/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev

```  

4.3.4 Creating the Kubernetes manifest and Ignition config files  
`$ openshift-install create manifests --dir ocp4/`  

  ### Configuring chrony time service  
  Create the contents of the chrony.conf file and encode it as base64.  
  ```
  $ cat << EOF | base64
    pool 0.rhel.pool.ntp.org iburst 
    driftfile /var/lib/chrony/drift
    makestep 1.0 3
    rtcsync
    logdir /var/log/chrony
  EOF
  ICAgIHNlcnZlciBjbG9jay5yZWRoYXQuY29tIGlidXJzdAogICAgZHJpZnRmaWxlIC92YXIvbGli
L2Nocm9ueS9kcmlmdAogICAgbWFrZXN0ZXAgMS4wIDMKICAgIHJ0Y3N5bmMKICAgIGxvZ2RpciAv
dmFyL2xvZy9jaHJvbnkK
  
  $ vi ocp4/openshift/99-masters-chrony-configuration.yaml
apiVersion: machineconfiguration.openshift.io/v1
kind: MachineConfig
metadata:
  labels:
    machineconfiguration.openshift.io/role: master
  name: 99-masters-chrony-configuration
spec:
  config:
    ignition:
      config: {}
      security:
        tls: {}
      timeouts: {}
      version: 3.2.0
    networkd: {}
    passwd: {}
    storage:
      files:
      - contents:
          source: data:text/plain;charset=utf-8;base64,ICAgIHNlcnZlciBjbG9jay5yZWRoYXQuY29tIGlidXJzdAogICAgZHJpZnRmaWxlIC92YXIvbGliL2Nocm9ueS9kcmlmdAogICAgbWFrZXN0ZXAgMS4wIDMKICAgIHJ0Y3N5bmMKICAgIGxvZ2RpciAvdmFyL2xvZy9jaHJvbnkK
        mode: 420
        overwrite: true
        path: /etc/chrony.conf
  osImageURL: ""
```

  masterSchedulable Parameter 변경  
  `$ vi ocp4/manifests/cluster-scheduler-02-config.yml`  
  mastersSchedulable: true -> false  

  Remove the Kubernetes manifest files that define the control plane machines and compute machine sets:  
  `$ rm -f openshift/99_openshift-cluster-api_master-machines-*.yaml openshift/99_openshift-cluster-api_worker-machineset-*.yaml`

4.3.5 Extracting the infrastructure name  
```
$ jq -r .infraID ocp4/metadata.json
ocp4-r7pml
```
4.4 Creating Red Hat Enterprise Linux CoreOS (RHCOS) machines in vSphere  
RHCOS와 관련된 ignition file의 http로 가져올 수 있도록 HTTP Server 준비할 것  
ignition file을 base64 encoding해서 VM의 환경변수로 입력하는 데, bootstrap.ign은 크기가 커서  
merge-bootstarp.ign을 작성하고, 내용에 실제 bootstrap.ign URL을 기입한다.  

```
$ cp ocp4/*.ign /var/www/html/ocp4/.
$ chown -R apache:apache /var/www/html
$ chmod 777 /var/www/html/ocp4/*

$ vi ocp4/merge-bootstrap.ign
{
"ignition": {
  "config": {
    "merge": [
      {
        "source": "http://172.20.2.110/ocp4/bootstrap.ign",
        "verification": {}
      }
    ]
  },
  "timeouts": {},
  "version": "3.2.0"
},
"networkd": {},
"passwd": {},
"storage": {},
"systemd": {}
}
```
ignition file encoding  
```
$ cd ocp4
$ base64 -w0 merge-bootstrap.ign > merge-bootstrap.64
$ base64 -w0 master.ign > master.64
$ base64 -w0 worker.ign > worker.64
```

여기서는 먼저 간단히 test 하기 위해 bootstrap 만 먼저 기동해본다.  (향후 terraform/ansible 자동화)  
Booting a new Core OS VM on VSphere ( ref: https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-vmware/ )  

Importing OVA  
```
$ RHCOS_OVA='Downloads/rhcos-vmware.x86_64.ova'  
$ LIBRARY='rhcos'  
$ TEMPLATE_NAME='rhcos-4.7.33'  
$ govc session.login -u 'user:password@host'  
$ govc library.create "${LIBRARY}"  
$ govc library.import -n "${TEMPLATE_NAME}" "${LIBRARY}" "${RHCOS_OVA}"  

Setting up a new VM
bootstrap config data
$ BOOTSTRAP_ENCODING_DATA=$(cat ocp4/merge-bootstrap.64;echo;)
$ echo $BOOTSTRAP_ENCODING_DATA
ewogICJpZ25pdGlvbiI6IHsKICAgICJjb25maWciOiB7CiAgICAgICJtZXJnZSI6IFsKICAgICAgICB7CiAgICAgICAgICAic291cmNlIjogImh0dHA6Ly8xNzIuMjAuMi4xMTAvb2NwNC9ib290c3RyYXAuaWduIiwgCiAgICAgICAgICAidmVyaWZpY2F0aW9uIjoge30KICAgICAgICB9CiAgICAgIF0KICAgIH0sCiAgICAidGltZW91dHMiOiB7fSwKICAgICJ2ZXJzaW9uIjogIjMuMi4wIgogIH0sCiAgIm5ldHdvcmtkIjoge30sCiAgInBhc3N3ZCI6IHt9LAogICJzdG9yYWdlIjoge30sCiAgInN5c3RlbWQiOiB7fQp9Cg==

$ VM_NAME='bootstrap'
$ LIBRARY='rhcos'
$ TEMPLATE_NAME='rhcos-4.7.33'
$ govc library.deploy "${LIBRARY}/${TEMPLATE_NAME}" "${VM_NAME}"
$ govc vm.change -vm "${VM_NAME}" -e "disk.EnableUUID=TRUE"
$ govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
$ govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${BOOTSTRAP_ENCODING_DATA}"
```  
bootstrap server ip 설정 reccommend  
회사 Network을 사용하므로 설정 전에 ip 사용 check할 것  
```
export IPCFG="ip=<ip>::<gateway>:<netmask>:<hostname>:<iface>:none nameserver=srv1 [nameserver=srv2 [nameserver=srv3 [...]]]"
$ export IPCFG="ip=172.20.2.253::172.20.0.1:255.255.252.0:::none nameserver=172.20.2.230"
$ govc vm.change -vm "${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"

$ govc vm.info -e "${VM_NAME}"
Name:           bootstrap
Path:         /Datacenter/vm/bootstrap
UUID:         421313a8-d3c7-c95e-a659-33602860fcdf
Guest name:   Red Hat Enterprise Linux 7 (64-bit)
Memory:       4096MB
CPU:          2 vCPU(s)
Power state:  poweredOff
Boot time:    <nil>
IP address:
Host:         172.20.2.225
ExtraConfig:
  nvram:                                     bootstrap.nvram
  svga.present:                              TRUE
  pciBridge0.present:                        TRUE
  pciBridge4.present:                        TRUE
  pciBridge4.virtualDev:                     pcieRootPort
  pciBridge4.functions:                      8
  pciBridge5.present:                        TRUE
  pciBridge5.virtualDev:                     pcieRootPort
  pciBridge5.functions:                      8
  pciBridge6.present:                        TRUE
  pciBridge6.virtualDev:                     pcieRootPort
  pciBridge6.functions:                      8
  pciBridge7.present:                        TRUE
  pciBridge7.virtualDev:                     pcieRootPort
  pciBridge7.functions:                      8
  hpet0.present:                             TRUE
  viv.moid:                                  eeeae248-a22a-4b6c-9302-5c4eeb2397ff:vm-1185:OMrUqCf+ghxgq/C1LsmtICdy1DNySDH3dD7m7HxIkjo=
  vmware.tools.internalversion:              0
  vmware.tools.requiredversion:              11360
  migrate.hostLogState:                      none
  migrate.migrationId:                       0
  migrate.hostLog:                           bootstrap-550274ea.hlog
  guestinfo.ignition.config.data.encoding:   base64
  guestinfo.ignition.config.data:            ewogICJpZ25pdGlvbiI6IHsKICAgICJjb25maWciOiB7CiAgICAgICJtZXJnZSI6IFsKICAgICAgICB7CiAgICAgICAgICAic291cmNlIjogImh0dHA6Ly8xNzIuMjAuMi4xMTAvb2NwNC9ib290c3RyYXAuaWduIiwgCiAgICAgICAgICAidmVyaWZpY2F0aW9uIjoge30KICAgICAgICB9CiAgICAgIF0KICAgIH0sCiAgICAidGltZW91dHMiOiB7fSwKICAgICJ2ZXJzaW9uIjogIjMuMi4wIgogIH0sCiAgIm5ldHdvcmtkIjoge30sCiAgInBhc3N3ZCI6IHt9LAogICJzdG9yYWdlIjoge30sCiAgInN5c3RlbWQiOiB7fQp9Cg==
  disk.EnableUUID:                           TRUE
  guestinfo.afterburn.initrd.network-kargs:  ip=172.20.2.50::172.20.0.1:255.255.252.0:::none nameserver=172.20.2.230

$ govc vm.power -on "${VM_NAME}"
```  
## Cluster 구성  
3개의 script를 통해 각 vm들을 기동시킨다. (craete_bootstrap.sh, create-controls.sh, create-computes.sh)  

아래 과정을 통해 설치 확인  

5.1 각 Node 상태 확인  
`$ oc get nodes`

Node가 Ready로 변경 되지 않을 경우 CSR 확인  
5.2 csr 승인  
    `$ oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs --no-run-if-empty oc adm certificate approve`

5.3 Cluster Operator 및 Version 확인  
```
$ oc get co
$ oc get ClusterVersion
```
정상 작동시 Chrony Service 가 추가 (설치시 구성하지 않았을 경우)  

아래 과정은 Operator Hub을 구성하기 위한 과정입니다.  
6. Disabling the default OperatorHub sources  
`$ oc patch OperatorHub cluster --type json -p '[{"op": "add", "path": "/spec/disableAllDefaultSources", "value": true}]'`
