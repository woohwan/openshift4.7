# 별도의 private network을 구성하지 않고, 회사 Network을 이용해서 cluster 구성



Base Domain: steve-ml.net 
cluster name: ocp4

구성 순서
1. DNS: AWS Route53 domain: steve-ml.net
2. Load Balancer 구성 ( CentOS 8)
  - ipo: 172.20.2.228, 
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
  [root@bastion ~]# nslookup api.ocp4.steve-ml.net
  Server:         172.20.2.230
  Address:        172.20.2.230#53

  Non-authoritative answer:
  Name:   api.ocp4.steve-ml.net
  Address: 172.20.2.228

template에서 vm 생성 후 ip 설정
회사 Network을 사용하므로 설정 전에 ip 사용 check할 것
export IPCFG="ip=<ip>::<gateway>:<netmask>:<hostname>:<iface>:none nameserver=srv1 [nameserver=srv2 [nameserver=srv3 [...]]]"
export IPCFG="ip=172.20.2.110::172.20.0.1:255.255.252.0:::none nameserver=8.8.8.8"
govc vm.change -vm "bastion" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"
govc vm.info

  4.1 SSH Private Key 생성 및 SSH-Agent에 추가
    4.1.1 - private key 생성 (passphrase: just Enter)
    $ Generating public/private rsa key pair.
    Enter file in which to save the key (/root/.ssh/id_rsa):
    Created directory '/root/.ssh'.
    Enter passphrase (empty for no passphrase):
    Enter same passphrase again:
    Your identification has been saved in /root/.ssh/id_rsa.
    Your public key has been saved in /root/.ssh/id_rsa.pub.
    The key fingerprint is:
    SHA256:yq32R3wcq/q/k5AqGMSt67MmnHCgZefhT/VZqE3s3AI root@bastion.ocp4.steve-ml.net
    The key's randomart image is:
    +---[RSA 3072]----+
    |                 |
    |                 |
    |   . .   . .     |
    |. o = . E + o    |
    |.+ = o .SX * o   |
    |o . =..o. % =    |
    | + . *o .o = .   |
    |  + = +.. o o    |
    |   +o+.oo+..oo   |
    +----[SHA256]-----+
  
    4.1.2 ssh-agent를 background로 수행
    $ eval "$(ssh-agent -s)"
    Agent pid 2509

    4.1.3 Add your SSH private key to the ssh-agen
    $ ssh-add
    Identity added: /root/.ssh/id_rsa (root@bastion.ocp4.steve-ml.net)

  4.2 Install program download
  CentOS 8의 Home directory bin directory ($HOME/bin)가 기본 path로 잡혀있다.
  bin 디렉토리를 만들고, 여기에 install program을 move한다.
  $ mkdir ~/bin
  
  download할 version: 4.7.33
  $ cd Download
  $ echo OCP_BASEURL= https://mirror.openshift.com/pub/openshift-v4/clients/ocp
  $ curl -L https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.7.33/openshift-client-linux-4.7.33.tar.gz |tar xzvf - -C ~/bin oc kubectl
  $ oc version
  Client Version: 4.7.33

  4.3 Manually create install-config.yaml file
    4.3.1 create installation config dir
    $ mkdir ocp4

    4.3.2 install-config.yaml file 생성
    $ vi install-config.yaml
----------------------------------------------------------------------------
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
pullSecret: '{"auths": ...}' 
sshKey: 'ssh-ed25519 AAAA...' 
-------------------------------------------------------------------------------------

    위 항목 중 datacenter, defaultDatastore, folder는 govc를 통해 정보를 얻거나 생성한다. (vSphere Client 사용 가능)
    govc는 govc-tip을 참고할 것

    $ govc folder.create $dc/vm/ocp4

    pullSecret은 https://console.redhat.com/openshift/install/pull-secret 에서 copy & paste
    sshKey는
    $ cat .ssh/id_rsa.pub;echo
    ssh-rsa ~

    output을 copy & paste

    4.3.4 Creating the Kubernetes manifest and Ignition config files


