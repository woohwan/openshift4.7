# download govc  
$ wget https://github.com/vmware/govmomi/releases/download/v0.27.2/govc_Linux_x86_64.tar.gz  

## Configure your Basic vCenter Connection  
cat vmc-govcvars.sh  
```
#!/bin/bash  
export GOVC_URL=vcsa.saltware.lab # Your SDDC / vCenter IP or FQDN
export GOVC_USERNAME=administrator@vsphere.local # vCenter username
export GOVC_PASSWORD=HIGHLYSECURE123 # vCenter password
export GOVC_INSECURE=1 # In order to NOT verify SSL certs on vCenter
```
-----------------------------------------------------------------  
`$ source vmc-govcvars.sh`

```
export GOVC_URL='root:password@<IPaddress>'  
export GOVC_INSECURE=1  
```  

위 기본정보를 이용하여 vCenter에 접속하여 datastore, network, resourece pool, folder 정보를 얻는다.  

기본 정보 나열  
```
$ govc about
FullName:     VMware vCenter Server 7.0.3 build-18700403
Name:         VMware vCenter Server
Vendor:       VMware, Inc.
Version:      7.0.3
Build:        18700403
OS type:      linux-x64
API type:     VirtualCenter
API version:  7.0.3.0
Product ID:   vpx
UUID:         eeeae248-a22a-4b6c-9302-5c4eeb2397ff

$ govc datacenter.info
Name:                Datacenter
  Path:              /Datacenter
  Hosts:             1
  Clusters:          1
  Virtual Machines:  15
  Networks:          2
  Datastores:        1

$ govc ls
/Datacenter/vm
/Datacenter/network
/Datacenter/host
/Datacenter/datastore
```  
```
# set variable 'dc' so we can use it later  
$ dc=$(govc ls /)

### Network
$ govc ls -l true $dc/network
/Datacenter/network/OCP (Network)
/Datacenter/network/VM Network (Network)

### Datastore
$ govc ls -l=true $dc/datastore
/Datacenter/datastore/datastore1 (Datastore)

### cluster name
$ govc ls $dc/host
/Datacenter/host/mycluster

### resource pool
$ govc ls -l 'host/*' | grep ResourcePool | awk '{print $1}' | xargs -n1 -t govc pool.info
```
```
export GOVC_DATASTORE=datastore1 # Default datastore to deploy to - Neccessary for deployments to VMC!
export GOVC_NETWORK=VM Network # Default network to deploy to
export GOVC_RESOURCE_POOL=/Datacenter/host/mycluster/Resources # Default resource pool to deploy t
export GOVC_FOLDER=starter # Default folder for our deployments
```

### Get VM Information  
#### basic info  
```
$ govc vm.info Bastion
Name:           Bastion
  Path:         /Datacenter/vm/starter/Bastion
  UUID:         421367d3-9e5b-ab5a-68a8-a76571098a76
  Guest name:   CentOS 8 (64-bit)
  Memory:       4096MB
  CPU:          4 vCPU(s)
  Power state:  poweredOn
  Boot time:    2021-12-14 15:52:02 +0000 UTC
  IP address:   172.20.2.110
  Host:         172.20.2.225
```  
##### for detail meta data  
```
vmpath=$(govc vm.info Bastion | grep "Path:" | awk {'print $2'})
govc ls -l -json $vmpath 
```
### Shutdown VM, power up VM  
gracefully shutdown guest OS using tools  
`$ govc vm.power -s=true myvm-001`

force immediate powerdown  
`$ govc vm.power -off=true myvm-001 `

power VM back on  
`$ govc vm.power -on=true myvm-001`

### Deploy the OVA  
```
$ govc import.ova -options=ubuntu.json ~/Downloads/ubuntu-18.04-server-cloudimg-amd64.ova

$ govc vm.change -vm Ubuntu1804Template -c 4 -m 4096 -e="disk.enableUUID=1"
$ govc vm.disk.change -vm Ubuntu1804Template -disk.label "Hard disk 1" -size 60G
```

Deploy VM from Template (govc vm.clone --help)  
`govc vm.clone -vm template-vm new-vm`







아래는 단순참고 사항

 Steps to Reproduce:
1. Create VM from OVA
2. Add all relevant Guestinfo properties by using the example

guestinfo.hostname = "coreos"
guestinfo.interface.0.role = "private"
guestinfo.dns.server.0 = "8.8.8.8"
guestinfo.interface.0.route.0.gateway = "192.168.178.1"
guestinfo.interface.0.route.0.destination = "0.0.0.0/0"
guestinfo.interface.0.mac = "00:0c:29:63:92:5c"
guestinfo.interface.0.name = "eno1*"
guestinfo.interface.0.dhcp = "no"



statici ip는 아래가 아니고,
guestinfo.interface.0.ip.0.address = "192.168.178.97/24"

 Using guestinfo.afterburn.initrd.network-kargs, I was able to set static IPs.

