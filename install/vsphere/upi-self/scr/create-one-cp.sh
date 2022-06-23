#!/bin/bash

# Create Control Plane
LIBRARY="rhcos"
TEMPLATE_NAME="rhcos-4.7.33"
BASE64_IGN_LOCATION="/root/ocp4/master.64"
VM_FOLDER="ocp4"

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

read -p "Insert VM Name: " VM_NAME
read -p "Insert IP Address: " IP_ADDR

#: << "END"
# create bootstrap VM
echo "Creating Control Plane VM"
echo "Creating '${VM_NAME}' ..."
govc library.deploy -folder="${VM_FOLDER}" "${LIBRARY}/${TEMPLATE_NAME}" "${VM_NAME}"
check_exit_code $? "Cannot create Control Plane VM"
#END

# Chnage VM Spec and Environment Varialbe
IGN_ENCODING=$(cat "${BASE64_IGN_LOCATION}";echo)

echo "Chnaging  Spec & Env vars of ${VM_NAME}"
govc vm.change -vm "${VM_NAME}" -c=4 -m=16384

govc vm.disk.change -vm "${VM_NAME}" -size 120G
govc vm.change -vm "${VM_NAME}" -e "disk.EnableUUID=TRUE"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${IGN_ENCODING}"

echo "Chnaging  IP Addr of ${VM_NAME}"
echo "IP Address is ${IP_ADDR}"
IPCFG="ip=${IP_ADDR}::172.20.0.1:255.255.252.0:${VM_NAME}.ocp4.steve-ml.net::none nameserver=172.20.2.230"

govc vm.change -vm "${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"