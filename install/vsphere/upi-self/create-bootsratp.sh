#!/bin/bash
VM_NAME=bootstrap
LIBRARY='rhcos'
TEMPLATE_NAME='rhcos-4.7.33'
BASE64_IGN_LOCATION='/root/ocp4/merge-bootstrap.64'
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
: << "END"
echo 'Creating Boosttrap VM'
govc library.deploy -folder="${VM_FOLDER}" "${LIBRARY}/${TEMPLATE_NAME}" "${VM_NAME}" 
check_exit_code $? "Cannot create Bootstrap VM"
END

# Chnage VM Spec and Environment Varialbe
echo 'Change VM Spec and Env Variable'
govc vm.change -vm "${VM_NAME}" -c=2 -m=8192
govc vm.disk.change -vm "${VM_NAME}" -size 120G
govc vm.change -vm "${VM_NAME}" -e "disk.EnableUUID=TRUE"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
IGN_ENCODING=$(cat "${BASE64_IGN_LOCATION}";echo)
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${IGN_ENCODING}"

export IPCFG="ip=172.20.2.253::172.20.0.1:255.255.252.0:boostrap.ocp4.steve-ml.net::none nameserver=172.20.2.230"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"

echo 'Bootstrap VM was created'