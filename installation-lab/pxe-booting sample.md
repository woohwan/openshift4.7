PXE 부팅을 위한 tftp 서버

PXE 부팅 파일은 디렉터리 /var/lib/tftpboot/pxelinux.cfg/에 배치해야 합니다. 모든 단일 MAC 주소에 서로 다른 PXE 부팅 파일을 사용하려면 파일 이름을 01-aa-bb-cc-dd-ee-ff로 지정하십시오. 여기서 aa-bb-cc-dd-ee-ff는 소문자로 된 MAC 주소로, 콜론 대신 하이픈을 사용합니다.

MAC 주소 52:54:00:00:32:09에 대한 PXE 부팅 파일의 예는 다음과 같습니다.
```  
[root@utility ~]# cat /var/lib/tftpboot/pxelinux.cfg/01-52-54-00-00-32-09
default menu.c32
prompt 0
timeout 0
menu title **** OpenShift 4 BOOTSTRAP PXE Boot Menu ****

label Install RHCOS 4.6.1 Bootstrap Node
 kernel http://192.168.50.254:8080/openshift4/images/rhcos-4.6.1-x86_64-live-kernel-x86_64
 append ip=dhcp rd.neednet=1 coreos.inst.install_dev=vda console=tty0 console=ttyS0 coreos.inst=yes coreos.live.rootfs_url=http://192.168.50.254:8080/openshift4/images/rhcos-4.6.1-x86_64-live-rootfs.x86_64.img coreos.inst.ignition_url=http://192.168.50.254:8080/openshift4/4.6.4/ignitions/bootstrap.ign initrd=http://192.168.50.254:8080/openshift4/images/rhcos-4.6.1-x86_64-live-initramfs.x86_64.img
 ```  