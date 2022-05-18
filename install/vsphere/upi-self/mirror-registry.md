### 이 문서는 redhat partner portal의 ocp4 disconnected deployment를 재작성한 것임.  


# Configure Bastion VM  
1. set an environment variable  
```export OCP_RELEASE=4.10.13```   
2. Download and extract the OpenShift CLI, or oc client, to your bastion  
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
sudo scp egistry.steve-ml.net:/opt/registry/certs/ca.pem /etc/pki/ca-trust/source/anchors
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

3.4 You can only use one pull secret when mirroring the images to your local container registry as well as when you install OpenShift, so you need to merge the pull secrets you created in the previous two steps into a single json file named merged_pullsecret.json. Remember that you created your pullsecret_config.json in step 3.4.  
```  
jq -c --argjson var "$(jq .auths $HOME/pullsecret_config.json)" '.auths += $var' $HOME/ocp_pullsecret.json > merged_pullsecret.json

jq . merged_pullsecret.json
```  
3.5 Set the following environment variables.   
```   
export OCP_RELEASE=4.10.13
export LOCAL_REGISTRY=registry.steve-ml.net:5000
export LOCAL_REPOSITORY=ocp4/openshift4
export LOCAL_SECRET_JSON=merged_pullsecret.json
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
