### Disk Partitioning ( var)  

**Kubernetes supports only two file system partitions. If you add more than one partition to the original configuration, Kubernetes cannot monitor all of them.**  

참고:  https://access.redhat.com/solutions/4952011  


2. 2번째 방법 - 클러스터 구성 후  
**Worker node가 clean한 최초 상테에서 수행**  
vSphere client를 통해 Hard Disk를 추가 (50G)  
각 worker ndoe 재시작  
재 시작 후 각 worker node에 접속해 lsblk를 통해 디스크가 정상적으로 부착되었는 지 확인   

2.1 Create a new file, such as mymc.yaml, with the following MachineConfig defined:  
Ensure that the following values match your environment:  

metadata.labels["machineconfiguration.openshift.io/role"] should match your MachineConfigPool (master,worker, or a custom pool)  
sdb should match your nodes secondary storage device (ie, /dev/sdb)  
Be sure to change this reference everywhere it occurs in the file  

2.2 Create the new MachineConfig  
```  
[root@bastion hv19]# oc create -f mymc.yaml
machineconfig.machineconfiguration.openshift.io/98-var-lib-containers created  
```  
Once the new MachineConfig is rendered, the applicable nodes will begin to be updated and rebooted.   
On reboot a new XFS filesytem will be created on the specified disk, the old container storage will be cleared, and the disk will be mounted to /var/lib/containers  


각 worker node에서 확인  
```  
[core@cptnod1 ~]$ lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0   120G  0 disk
├─sda1   8:1    0     1M  0 part
├─sda2   8:2    0   127M  0 part
├─sda3   8:3    0   384M  0 part /boot
└─sda4   8:4    0 119.5G  0 part /sysroot
sdb      8:16   0    50G  0 disk /var/lib/containers
```  