#!/usr/bin/bash
VM_NAME=bootstrap
LIBRARY='rhcos-hv19'
TEMPLATE_NAME='rhcos-hv19-4.10.13'
NETWORK='OCP Network'
BASE64_IGN_LOCATION='/home/admin/vmware/ocp4/merge-bootstrap.64'
VM_FOLDER='ocp4'

function check_exit_code() {
        if [[ $1 -ne 0 ]]
        then
                echo $2
                echo "Please check the reason of problem and restart script"
                exit 1
        else
                echo "OK"
        fi
}

# create bootstrap VM
#: << "END"
echo 'Creating Boosttrap VM'
govc vm.clone -vm RHCOS -folder="${VM_FOLDER}" -on=false "${VM_NAME}"
check_exit_code $? "Cannot create Bootstrap VM"
#END

# Chnage VM Spec and Environment Varialbe
echo 'Change VM Spec and Env Variable'
#govc vm.upgrade -version=15 -vm "${VM_NAME}"
govc vm.network.add -net "${NETWORK}" -vm "${VM_NAME}"
govc vm.change -vm "${VM_NAME}" -c=2 -m=8192
govc vm.disk.change -vm "${VM_NAME}" -size 120G
govc vm.change -vm "${VM_NAME}" -e "disk.EnableUUID=TRUE"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
IGN_ENCODING=$(cat "${BASE64_IGN_LOCATION}";echo)
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${IGN_ENCODING}"

export IPCFG="ip=192.168.150.20::192.168.150.1:255.255.255.0:boostrap.mycluster.example.com::none nameserver=192.168.150.1"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"

echo 'Bootstrap VM was created'
echo 'Starting Bootstrap'
govc vm.power -on bootstrap
