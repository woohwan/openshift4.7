### 이 문서는 redhat partner portal의 ocp4 disconnected deployment를 재작성한 것임.  
참고: https://docs.openshift.com/container-platform/4.10/installing/installing_vsphere/installing-restricted-networks-vsphere.html  


# Configure Bastion VM  
1. set an environment variable  
```  
export OCP_RELEASE=4.10.13
```   
2. create working directory. 
```
mkdir $disconnected
```  
   
3. Download and extract the OpenShift CLI, or oc client, to your bastion  
```wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/$OCP_RELEASE/openshift-client-linux-$OCP_RELEASE.tar.gz```  
3. extract it to a location that will make it easy to use.  
```  
sudo tar xzf openshift-client-linux-$OCP_RELEASE.tar.gz -C /usr/local/sbin/ oc kubectl
which oc; oc version
```  
# Deploy Container Registry  

1. podman 동작여부 확인  
```
podman pull ubi8/ubi:8.3
podman run ubi8/ubi:8.3 cat /etc/os-release
```  
2. Create directories for your data, auth, and certificates that will be used by the container registry. Because you will use these directories and files in your container, you will need to change permissions as well to run as a regular use  
```  
sudo mkdir -p /opt/registry/{auth,certs,data}

sudo chown -R $USER /opt/registry
```  
## Updating Golang Certificate Libraries  
인증서를 만들기 위해 cfssl을 사용한다.  
1. First get the required binaries  
```
sudo wget --quiet https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssljson_1.5.0_linux_amd64 -O /usr/local/bin/cfssljson

sudo wget --quiet https://github.com/cloudflare/cfssl/releases/download/v1.5.0/cfssl_1.5.0_linux_amd64 -O /usr/local/bin/cfssl

sudo chmod 755 /usr/local/bin/cfssl /usr/local/bin/cfssljson

cfssl version ; cfssljson --version
```  
2. Define how are we going to create the certificate using ca-config.json, ca-csr.json and server.json files  
```  
cd /opt/registry/certs

cat << EOF > ca-config.json
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "server": {
        "expiry": "87600h",
        "usages": [
          "signing",
          "key encipherment",
          "server auth"
        ]
      },
      "client": {
        "expiry": "87600h",
        "usages": [
          "signing",
          "key encipherment",
          "client auth"
        ]
      }
    }
  }
}
EOF

cat << EOF > ca-csr.json
{
  "CN": "Saltware OSS",
  "hosts": [
    "registry.steve-ml.net"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "KR",
      "ST": "Seoul",
      "L": "GuroGu",
      "OU": "OSS"
    }
  ]
}
EOF

cat << EOF > server.json
{
  "CN": "Saltware OSS",
  "hosts": [
    "registry.steve-ml.net"
  ],
  "key": {
    "algo": "ecdsa",
    "size": 256
  },
  "names": [
    {
      "C": "KR",
      "ST": "Seoul",
      "L": "GuroGu",
      "OU": "OSS"
    }
  ]
}
EOF
```  
3. Then generate the certificate using cfssl  
```  
cfssl gencert -initca ca-csr.json | cfssljson -bare ca -

cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=server server.json | cfssljson -bare server
```  

4. Now you can see both ca and server pem files have v3 SAN extension enabled  
```
openssl x509 -in ca.pem -text -noout  | grep X509v3 -A 1

openssl x509 -in server.pem -text -noout  | grep X509v3 -A 1
```  
5. Since this registry will be secured, create a username and password. You are using htpasswd as the authentication mechanism, so you will need to add these to a file that will be mounted into the container registry.  
```htpasswd -bBc /opt/registry/auth/htpasswd openshift redhat```
This will create a user named openshift with a password of redhat  

6. At this point, all of the requirements necessary to start your container registry shoudl be satisfied. You will now use rootless podman to start the container.  
```
podman run -d --name mirror-registry \
  -p 5000:5000 --restart=always \
  -v /opt/registry/data:/var/lib/registry:z \
  -v /opt/registry/auth:/auth:z \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  -v /opt/registry/certs:/certs:z \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/server.pem \
  -e REGISTRY_HTTP_TLS_KEY=/certs/server-key.pem \
  docker.io/library/registry:2  
  ```   
  The container registry starts with the following options:  
  - It is listening on port 5000  
  - It has htpasswd authentication configured and is using the file you created   
  - It is using the certificates you created  

7. Test your connection to the registry.  
```curl -u openshift:redhat -k https://registry.steve-ml.net:5000/v2/_catalog```  

>>Sample output  
{"repositories":[]}  

8. Test your connection without bypassing the TLS check.  
```curl -u openshift:redhat https://registry.steve-ml.net:5000/v2/_catalog```  

Sample Output  
```
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.  
```  
  - The first test that ignores the self-signed certificates completes successfully  
  - The second test that does not ignore the self-signed certificates fails  

9. Since your container registry is secured and OpenShift will not tolerate untrusted certificates, you must add the certificates to your trusted store.  
```  
sudo cp /opt/registry/certs/ca.pem /etc/pki/ca-trust/source/anchors
sudo update-ca-trust extract
curl -u openshift:redhat https://registry.steve-ml.net:5000/v2/_catalog 
```  
>>Sample output  
{"repositories":[]}  

10. Test to ensure you can push and pull an image from the container registry.  
sigature error 발생해서 --remove-signatures 추가    
```  
podman pull ubi8/ubi:8.3
podman login -u openshift -p redhat registry.steve-ml.net:5000
podman tag registry.access.redhat.com/ubi8/ubi:8.3 registry.steve-ml.net:5000/ubi8/ubi:8.3
podman push registry.steve-ml.net:5000/ubi8/ubi:8.3 --remove-signatures
```  

11.  Verify that the image you pushed is being written to the correct location in the file system of your Utility VM. You should see a single folder named ubi8.  
```ls /opt/registry/data/docker/registry/v2/repositories```
>> Sample output  
ubi8  

12.  back to the Bastion VM  

# Mirror Content  
on Bastion VM curl test 및 ca.pem을 trust store에 등록
1. curl check  
```curl -u openshift:redhat https://registry.steve-ml.net:5000/v2/_catalog```  
>>Sample output
```  
curl: (60) SSL certificate problem: unable to get local issuer certificate
More details here: https://curl.haxx.se/docs/sslcerts.html

curl failed to verify the legitimacy of the server and therefore could not
establish a secure connection to it. To learn more about this situation and
how to fix it, please visit the web page mentioned above.
```  
2. ou haven’t added the new self-signed certificate to your trusted store on the bastion. Do this and test again.  
```  
sudo scp registry.steve-ml.net:/opt/registry/certs/ca.pem /etc/pki/ca-trust/source/anchors
sudo update-ca-trust
curl -u openshift:redhat https://registry.steve-ml.net:5000/v2/_catalog   
```  

3. You can now connect to your local container registry. Proceed by mirroring all of the content necessary to install OpenShift 4.  
  - Create a pull secret for your new container registry running on your Utility VM  
  - Create a file with your OpenShift pull secret  
  - Merge your pull secrets into a single json file that you will use for both mirroring and installing  
  - Mirror the content to your local container registry  
3.1 Create a pull secret that can be used to push content into the container registry  
```podman login -u openshift -p redhat --authfile $HOME/pullsecret_config.json registry.steve-ml.net:5000```  
3.2 Look at the json file you created in the previous command. This file now includes the container registry hostname as well as an authentication token based on the credentials you provided in the podman command.  
```cat $HOME/pullsecret_config.json```  
>>Sample output
```
{
        "auths": {
                "registry.steve-ml.net:5000": {
                        "auth": "b3BlbnNoaWZ0OnJlZGhhdA=="
                }
        }
}
```
3.3 That is one of the credentials you need. The other is the OpenShift pull secret that you got from Red Hat. Add that to a file called $HOME/ocp_pullsecret.json.  

3.4 You can only use one pull secret when mirroring the images to your local container registry as well as when you install OpenShift, so you need to merge the pull secrets you created in the previous two steps into a single json file named merged_pullsecret.json. Remember that you created your pullsecret_config.json in step 3.1.  
```  
jq -c --argjson var "$(jq .auths $HOME/pullsecret_config.json)" '.auths += $var' $HOME/ocp_pullsecret.json > $HOME/merged_pullsecret.json

jq . $HOME/merged_pullsecret.json
```  
3.5 Set the following environment variables.   
```   
export OCP_RELEASE=4.10.13
export LOCAL_REGISTRY=registry.steve-ml.net:5000
export LOCAL_REPOSITORY=ocp4/openshift4
export LOCAL_SECRET_JSON=$HOME/merged_pullsecret.json
export PRODUCT_REPO=openshift-release-dev
export RELEASE_NAME=ocp-release
export ARCHITECTURE=x86_64
```  
3.6 All of your pre-requisites are finally complete and you are ready to mirror the OpenShift 4 content to your local container registry! As discussed earlier, the process in OpenShift 4 is much easier than it used to be. The following command will do everything necessary. Run this on your bastion.  
```  
oc adm -a ${LOCAL_SECRET_JSON} release mirror \
   --from=quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE} \
   --to=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY} \
   --to-release-image=${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}
```     
  Make note of the output. You will need to use the imageContentSources in the next sectio  

3.7 To verify that all the images are indeed available in your container registry, try pulling one. Note that you’ll have to provide your authfile since you are not logged in to the container registry with podman  
'''
podman pull --authfile $HOME/pullsecret_config.json registry.steve-ml.net:5000/ocp4/openshift4:$OCP_RELEASE-$ARCHITECTURE-operator-lifecycle-manager
'''  
Sample Output
```   
Trying to pull registry.steve-ml.net:5000/ocp4/openshift4:4.10.13-x86_64-operator-lifecycle-manager...
Getting image source signatures
Copying blob da5839e0efa1 done
Copying blob 67c4675a80ba done
Copying blob 39382676eb30 done
Copying blob 237bfbffb5f2 done
Copying blob 63fa182ce8dd done
Copying config 0b48c5c2fd done
Writing manifest to image destination
Storing signatures
0b48c5c2fd1c334d0ddb905a031f49f4b6186df84227fb29a76d061d5bb03a32   
```  
3.8 Make sure the new image shows up in your local image storage on the bastion  
```podman images```  
```  
REPOSITORY                                  TAG                                        IMAGE ID      CREATED      SIZE
registry.steve-ml.net:5000/ocp4/openshift4  4.10.13-x86_64-operator-lifecycle-manager  0b48c5c2fd1c  3 weeks ago  646 MB
```  
3.9 Take a minute to verify the version information you have downloaded. Again, you can use the oc adm release command.  
```  
oc adm release info -a ${LOCAL_SECRET_JSON} "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}" | head -n 18  
```  
Sample Output  
```  
Name:      4.10.13
Digest:    sha256:4f516616baed3cf84585e753359f7ef2153ae139c2e80e0191902fbd073c4143
Created:   2022-05-04T14:43:42Z
OS/Arch:   linux/amd64
Manifests: 542

Pull From: registry.steve-ml.net:5000/ocp4/openshift4@sha256:4f516616baed3cf84585e753359f7ef2153ae139c2e80e0191902fbd073c4143

Release Metadata:
  Version:  4.10.13
  Upgrades: 4.9.19, 4.9.21, 4.9.22, 4.9.23, 4.9.24, 4.9.25, 4.9.26, 4.9.27, 4.9.28, 4.9.29, 4.9.30, 4.9.31, 4.9.32, 4.10.3, 4.10.4, 4.10.5, 4.10.6, 4.10.7, 4.10.8, 4.10.9, 4.10.10, 4.10.11, 4.10.12
  Metadata:
    url: https://access.redhat.com/errata/RHBA-2022:1690

Component Versions:
  kubernetes 1.23.5
  machine-os 410.84.202204291735-0 Red Hat Enterprise Linux CoreOS
  ```  

3.10 You can compare this information with what you would get from doing a connected install. Run the same command, but point it to the Red Hat repositories hosted on quay.io. Except for the "Pull From" line, this should look identical to your output above.  
```  
oc adm release info -a ${LOCAL_SECRET_JSON} "quay.io/${PRODUCT_REPO}/${RELEASE_NAME}:${OCP_RELEASE}-${ARCHITECTURE}" | head -n 18  
```
  위와 동일한지 확인  

### Catalog mirroring  


# Prepare Installation artifact  
## Obtaining the installation program  
1. On your bastion, run the following command. This will extract the openshift-install binary from images you have already mirrored. The openshift-install binary will then exist and be executable on your bastion. This ensures you have a version of the installer that matches the payload and images your downloaded  
```  
oc adm release extract -a ${LOCAL_SECRET_JSON} --command=openshift-install "${LOCAL_REGISTRY}/${LOCAL_REPOSITORY}:${OCP_RELEASE}-${ARCHITECTURE}"  
```    
  openshift-install command 확인  

2. Copy this file to a location that is in your $PATH and will make it easier to use.  
```  
sudo mv openshift-install /usr/local/sbin
```  

3. Validate that your openshift-install is executable and that you are running an expected version pulled from an expected location.  
```  
openshift-install version
```  
Sample Output  
openshift-install 4.10.13
built from commit ed025ee9ca62dd3fb7f7f7eaff9c90fd1a011fe2
release image registry.steve-ml.net:5000/ocp4/openshift4@sha256:4f516616baed3cf84585e753359f7ef2153ae139c2e80e0191902fbd073c4143   

4. Now that you have the installer, you are ready to begin continuing the preparation for your installation.  
   
## Generating a key pair for cluster node SSH access  
1. To use for authentication onto your cluster nodes, create SSH key pair
```  
ssh-keygen -t ed25519
```  
2. View the public SSH key  
```
cat ~/.ssh/id_ed25519.pub  
```  
3. Add the SSH private key identity to the SSH agent  
```
eval "$(ssh-agent -s)"
```  
Sample Output
Agent pid 31874
4.  Add your SSH private key to the ssh-agent  
```  
ssh-add
```  
Sample Output
Identity added: /home/<you>/<path>/<file_name> (<computer_name>)  

## Adding vCenter root CA certificates to your system trust  
1. From the vCenter home page, download the vCenter’s root CA certificates. Click Download trusted root CA certificates in the vSphere Web Services SDK section. The <vCenter>/certs/download.zip file downloads.  
```
wget vcsa.steve-ml.net/certs/download.zip  
```  
2. Extract the compressed file that contains the vCenter root CA certificates. The contents of the compressed file resemble the following file structure:  
```  
unzip download.zip  
tree certs
```  
certs/  
├── lin  
│   ├── b1dd9126.0  
│   └── b1dd9126.r1  
├── mac  
│   ├── b1dd9126.0  
│   └── b1dd9126.r1  
└── win  
    ├── b1dd9126.0.crt  
    └── b1dd9126.r1.crl   
```
3. Add the files for your operating system to the system trust. For example, on a Fedora operating system, run the following command  
```  
cp certs/lin/* /etc/pki/ca-trust/source/anchors  
```  
4. Update your system trust. For example, on a Fedora operating system, run the following command  
```  
update-ca-trust extract  
```  

# Deploying the cluster  
vCenter 설치 시 cluster 구성 후 host 추가  
( cluster 구성도: vcsa.steve-ml.net -> Datacenter -> mycluster -> host )  

## intall config file 생성 및 수정
1. install-config file 생성  
```  
cd $HOME/disconnected
mkdir config
openshift-install create install-config --dir config 
```   
```  
? SSH Public Key /root/.ssh/id_rsa.pub
? Platform vsphere
? vCenter vcsa.steve-ml.net
? Username administrator@vsphere.local
? Password [? for help] **********
INFO Connecting to vCenter vcsa.steve-ml.net
INFO Defaulting to only available datacenter: Datacenter
INFO Defaulting to only available cluster: mycluster
INFO Defaulting to only available datastore: datastore1
? Network VM Network
? Virtual IP Address for API 172.20.2.228
? Virtual IP Address for Ingress 172.20.2.229
? Base Domain steve-ml.net
? Cluster Name ocp4
? Pull Secret [? for help] *****************
```
pull Secret에 대해서 아래 명령 수행후 copy & paste  
```  
cat merged_pullsecret.json  
```  

2. install-config 수정  
UPI Installation설치이므로  아래 smaple을 참고하여 수정한다.  
위 install-config 생성은 자동으로 생성된 것이므로 수정이 필요하다. 그렇지 않을 경우,  
IPI설치와 동일한 방법이므로 bootstrap node가 API가 vip를 가져가므로 기존에 설치한 haproxy와 충돌한다.  
platform.vsphere 부분만 수정하면 된다.  
```  
apiVersion: v1
baseDomain: example.com 
compute: 
- hyperthreading: Enabled 
  name: worker
  replicas: 0 
controlPlane: 
  hyperthreading: Enabled 
  name: master
  replicas: 3 
metadata:
  name: test 
platform:
  vsphere:
    vcenter: your.vcenter.server 
    username: username 
    password: password 
    datacenter: datacenter 
    defaultDatastore: datastore 
    folder: "/<datacenter_name>/vm/<folder_name>/<subfolder_name>" 
    resourcePool: "/<datacenter_name>/host/<cluster_name>/Resources/<resource_pool_name>" 
    diskType: thin 
fips: false 
pullSecret: '{"auths":{"<local_registry>": {"auth": "<credentials>","email": "you@example.com"}}}' 
sshKey: 'ssh-ed25519 AAAA...' 
additionalTrustBundle: | 
  -----BEGIN CERTIFICATE-----
  ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
  -----END CERTIFICATE-----
imageContentSources: 
- mirrors:
  - <local_registry>/<local_repository_name>/release
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - <local_registry>/<local_repository_name>/release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```  

- Adding the Registry CA  
  Add the additionalTrustBundle parameter and value.  
```
cd config
echo "additionalTrustBundle: |" >> install-config.yaml  
cat /etc/pki/ca-trust/source/anchors/ca.pem | sed -e 's/^/  /' >> install-config.yaml  
```  

- Add the image content resources below baseDomain item in install-config.yaml file
  To complete these values, use the imageContentSources that you recorded during mirror registry creation
```  
imageContentSources:
- mirrors:
  - registry.steve-ml.net:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - registry.steve-ml.net:5000/ocp4/openshift4
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
```    

1. backup install-config file
이후 openshift-install 작업은 install-config.yaml을 삭제하므로 미리 backup을 받는다.
```  
mkdir $HOME/disconnected/backup
cd $HOME/disconnected
cp config/install-config.yaml $HOME/disconnected/backup/.
ls $HOME/disconnected/backup
```  
## manifests file  생성 및 수정  
openshift-install create manifests --dir config

Change masterSchedulable Parameter  
```  
sed -i "s/ mastersSchedulable: true/ mastersSchedulable: false/" config/manifests/cluster-scheduler-02-config.yml
cat config/manifests/cluster-scheduler-02-config.yml
```  

Remove the Kubernetes manifest files that define the control plane machines and compute machine sets:  
```  
rm -f config/openshift/99_openshift-cluster-api_master-machines-*.yaml config/openshift/99_openshift-cluster-api_worker-machineset-*.yaml
```  

## Configuring chrony time service  
butane install: https://access.redhat.com/documentation/en-us/openshift_container_platform/4.10/html/installing/installation-configuration  

```  
curl https://mirror.openshift.com/pub/openshift-v4/clients/butane/latest/butane --output butane
chmod +x butane

```

1. Create a Butane config including the contents of the chrony.conf file  
- For master  
```  
cat << EOF > 99-master-chrony.bu
variant: openshift
version: 4.10.0
metadata:
  name: 99-worker-chrony 
  labels:
    machineconfiguration.openshift.io/role: master
storage:
  files:
  - path: /etc/chrony.conf
    mode: 0644 
    overwrite: true
    contents:
      inline: |
        pool 0.rhel.pool.ntp.org iburst 
        driftfile /var/lib/chrony/drift
        makestep 1.0 3
        rtcsync
        logdir /var/log/chrony
EOF
```  
butane 99-worker-chrony.bu -o 99-master-chrony.yaml

- For worker
```  
cat << EOF > 99-worker-chrony.bu
variant: openshift
version: 4.10.0
metadata:
  name: 99-worker-chrony 
  labels:
    machineconfiguration.openshift.io/role: worker 
storage:
  files:
  - path: /etc/chrony.conf
    mode: 0644 
    overwrite: true
    contents:
      inline: |
        pool 0.rhel.pool.ntp.org iburst 
        driftfile /var/lib/chrony/drift
        makestep 1.0 3
        rtcsync
        logdir /var/log/chrony
EOF
```  
butane 99-worker-chrony.bu -o 99-worker-chrony.yaml
cp 99-master-chrony.yaml 99-worker-chrony.yaml config/openshift/

## Create ingtion file  
vmware용 RHCOS를 사용할 예정으므로 이에 필요한 igntion file을 생성 및 수정한다. 
그리고, 이 파일을 deploy하기 위해 httpd 설치 및 구성을 한다.  
```  
openshift-install create ignition-configs --dir config  
```  
```  
INFO Consuming Master Machines from target directory
INFO Consuming Common Manifests from target directory
INFO Consuming OpenShift Install (Manifests) from target directory
INFO Consuming Worker Machines from target directory
INFO Consuming Openshift Manifests from target directory
INFO Ignition-Configs created in: config and config/auth
```  
### Copy ignition file to httpd root/ocp4 directory
```
rm -f /var/www/html/ocp4/*
cp config/*.ign /var/www/html/ocp4/.
chown -R apache:apache /var/www/html
chmod 777 /var/www/html/ocp4/*
ll /var/www/html/ocp4/
```  

Create merge bootstrap file  
```
cat << EOF > config/merge-bootstrap.ign
{
"ignition": {
  "config": {
    "merge": [
      {
        "source": "http://172.20.2.191/ocp4/bootstrap.ign",
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
EOF
```  
ignition file encoding
```  
cd config
base64 -w0 merge-bootstrap.ign > merge-bootstrap.64
base64 -w0 master.ign > master.64
base64 -w0 worker.ign > worker.64
cd ..
ll config
```  

### Red Hat 제공 OVA는 default로 Hardware Version 13으로 설정되어 있어 변경 필요  
### Modifying OVF metadata  
참고: https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-vmware/   
```  
While we provide these instructions for modifying the OVF metadata, we cannot guarantee that any modifications to the OVF metadata will result in a usable guest VM.
Fedora CoreOS is intended to run on generally supported releases of VMware ESXi, VMware Workstation, and VMware Fusion. Accordingly, the Fedora CoreOS VMware OVA image specifies a virtual hardware version that may not be compatible with older, unsupported VMware products. However, you can modify the image’s OVF metadata to specify an older virtual hardware version.

The VMware OVA is simply a tarball that contains the files disk.vmdk and coreos.ovf. In order to edit the metadata used by FCOS as a guest VM, you should untar the OVA artifact, edit the OVF file, then create a new OVA file.

The example commands below change the OVF hardware version from the preconfigured value to hardware version 13. (Note: the defaults in the OVF are subject to change.)

tar -xvf fedora-coreos-36.20220505.3.2-vmware.x86_64.ova
sed -iE 's/vmx-[0-9]*/vmx-13/' coreos.ovf
tar -H posix -cvf fedora-coreos-36.20220505.3.2-vmware-vmx-13.x86_64.ova coreos.ovf disk.vmdk
```  

### Test Bootstap Node
```
BOOTSTRAP_ENCODING_DATA=$(cat config/merge-bootstrap.64;echo;)
echo $BOOTSTRAP_ENCODING_DATA

VM_NAME='bootstrap'
LIBRARY='rhcos'
TEMPLATE_NAME='rhcos-4.10.13'
govc library.deploy "${LIBRARY}/${TEMPLATE_NAME}" "${VM_NAME}"
govc vm.change -vm "${VM_NAME}" -e "disk.EnableUUID=TRUE"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${BOOTSTRAP_ENCODING_DATA}"

export IPCFG="ip=172.20.2.253::172.20.0.1:255.255.252.0:::none nameserver=172.20.2.230"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"

govc vm.info -e "${VM_NAME}"

govc vm.power -on "${VM_NAME}"
```
### 스크립트 수행  
```  
create-bootstrap.sh
create-controls.sh
```  
### 설치 모니터링
1. bootstrap node & controlplane
```
openshift-install wait-for bootstrap-complete --dir config --log-level debug
```
```  
DEBUG OpenShift Installer 4.10.13
DEBUG Built from commit ed025ee9ca62dd3fb7f7f7eaff9c90fd1a011fe2
INFO Waiting up to 20m0s (until 1:50PM) for the Kubernetes API at https://api.ocp4.steve-ml.net:6443...
INFO API v1.23.5+b463d71 up
INFO Waiting up to 30m0s (until 2:00PM) for bootstrapping to complete...
DEBUG Bootstrap status: complete
INFO It is now safe to remove the bootstrap resources
INFO Time elapsed: 0s
```  
bootstrap node 완료 후, 위 내용처럼 bootstrap node삭제 및 haproxy에서 bootstrap node를 comment처리한다.  

Control Plane이 정상적으로 start up되었는지 확인한다.  
```
export KUBECONFIG=$HOME/disconnected/config/auth/kubeconfig
oc get nodes
```  
2. worker node 추가  
```  
create-computes.sh
```  
- csr 승인: compute node가 추가되면서 node관련 csr request    
```  
oc get csr
```  

pending state의 csr 승인  (주기적으로 check)
```  
oc adm certificate approve <csr_name>
```  
To approve all pending CSRs, run the following command:  
```  
oc get csr -o go-template='{{range .items}}{{if not .status}}{{.metadata.name}}{{"\n"}}{{end}}{{end}}' | xargs oc adm certificate approve
```  
monitoring
```  
oc get csr -o jsonpath='{ range .items[*]}{.spec.username}{"\t"}{.status.conditions[*].type}{"\n"}{end}'
```  
```  
system:serviceaccount:openshift-machine-config-operator:node-bootstrapper       Approved
system:serviceaccount:openshift-machine-config-operator:node-bootstrapper       Approved
system:node:cp2.ocp4.steve-ml.net       Approved
system:node:cptnod0.ocp4.steve-ml.net   Approved
system:serviceaccount:openshift-machine-config-operator:node-bootstrapper       Approved
system:node:cptnod1.ocp4.steve-ml.net   Approved
system:node:cp0.ocp4.steve-ml.net       Approved
system:serviceaccount:openshift-machine-config-operator:node-bootstrapper       Approved
system:serviceaccount:openshift-machine-config-operator:node-bootstrapper       Approved
system:node:cp1.ocp4.steve-ml.net       Approved
system:serviceaccount:openshift-authentication-operator:authentication-operator Approved
system:serviceaccount:openshift-monitoring:cluster-monitoring-operator  Approved
```  

3. install complete 모니터링  
```  
openshift-install wait-for install-complete --dir config --log-level debu
g
```  
```  
INFO Install complete!
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/root/disconnected/config/auth/kubeconfig'
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.ocp4.steve-ml.net
INFO Login to the console with user: "kubeadmin", and password: "OOOOOOOOOOOO"
DEBUG Time elapsed per stage:
DEBUG Cluster Operators: 25m10s
INFO Time elapsed: 25m10s  
```  
나중에 tail -f config/.openshift_install.log 통해서도 확인 가능

cluster operator 확인
```  
oc get co
``` 

설치 완료 확인  
```  
openshift-install wait-for bootstrap-complete --dir config --log-level debug  
```  

4. web console access  
web console에 접근하기 위해서는 cluster가 사용하는 Name Server에 연결되어 있어야 한다.
여기서는 외부접근을 가능하게 하기 위해  api와 apps에 관련 dns을 AWS route53에 등록한다.
*.apps.ocp4.steve-ml.net  172.20.2.228
api.ocp4.steve-ml.net  172.20.2.228

ref: oc whoami --show-console  


# TroubleShooting  
참고 url: https://docs.openshift.com/container-platform/4.10/support/troubleshooting/troubleshooting-installations.html  

```  
ssh -i <path_to_private_SSH_key> core@<bootstrap_ip>
journalctl -b -f -u release-image.service -u bootkube.service
```  

- x509: certificate has expired or is not yet valid: current time 2022-05-19T04:38:58Z is before 2022-05-19T10:15:07Z  --> https://access.redhat.com/solutions/6339541  : ntp 맞추줄 것. hardware

- 6443 connection refused  --> bootstrap이 완전이 올라올때 까지 기다릴 것

 - failed to list *v1.ConfigMap  --> pull Secret 수정. mirror registry에 email 추가함  (?)  
 --> UPI install이기 때문에 install-config.yaml file에 API & Ingress VIP가 있으면 안된다.  
 IPI install처럼 bootstrap node에서 API VIP를 구성하기때문에 HA Proxy를 별도로 구성하는 UPI에서는 API VIP가
 충돌한다.  

- Cluster Operator auth, ingress 에러가 날 경우 csr이 모두 approve가 되었는지 확인.   
  위 내용을 보면 control plane, compute node 각각 2개씩 총 10개,   
  그리고 authentication, monitoring operator 하나씩  


### add Infra nodes  
```  
oc label node <node-name> node-role.kubernetes.io/infra=

oc adm taint nodes -l node-role.kubernetes.io/infra node-role.kubernetes.io/infra=reserved:NoSchedule node-role.kubernetes.io/infra=reserved:NoExecute
```  


work role 제거
```  
oc label node  infra0.ocp4.steve-ml.net node-role.kubernetes.io/worker-
```  








