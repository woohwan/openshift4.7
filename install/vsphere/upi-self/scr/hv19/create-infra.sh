#!/bin/bash
LIBRARY="rhcos-hv19"
TEMPLATE_NAME="rhcos-hv19-4.10.13"
BASE64_IGN_LOCATION="/root/disconnected/config/worker.64"
VM_FOLDER="ocp4"

declare -A VM_IP_MAP
VM_IP_MAP+=([infra2]=172.20.2.249)
VM_IP_MAP+=([infra1]=172.20.2.248)
VM_IP_MAP+=([infra0]=172.20.2.247)

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

# create compute node VM
echo "Creating Control Plane VMs"
#: << "end"
for VM_NAME in ${!VM_IP_MAP[@]}; do
        echo "Creating '${VM_NAME}' ..."
        govc library.deploy -folder="${VM_FOLDER}" "${LIBRARY}/${TEMPLATE_NAME}" "${VM_NAME}"
        check_exit_code $? "Cannot create Control Plane VM"

done
#end

# Chnage VM Spec and Environment Varialbe
IGN_ENCODING=$(cat "${BASE64_IGN_LOCATION}";echo)
echo $IGN_ENCODING

echo "Change VM Spec and Env Variable"
for VM_NAME in ${!VM_IP_MAP[@]}; do
        echo "Chnaging  Spec & Env vars of ${VM_NAME}"
#       govc vm.upgrade -version=19 -vm "${VM_NAME}"
        govc vm.change -vm "${VM_NAME}" -c=2 -m=4096

        govc vm.disk.change -vm "${VM_NAME}" -size 120G
        govc vm.change -vm "${VM_NAME}" -e "disk.EnableUUID=TRUE"
        govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data.encoding=base64"
        govc vm.change -vm "${VM_NAME}" -e "guestinfo.ignition.config.data=${IGN_ENCODING}"

        echo "Chnaging  IP Addr of ${VM_NAME}"
        IPCFG="ip=${VM_IP_MAP[$VM_NAME]}::172.20.0.1:255.255.252.0:${VM_NAME}.ocp4.steve-ml.net::none nameserver=172.20.2.230"

        govc vm.change -vm "${VM_NAME}" -e "guestinfo.afterburn.initrd.network-kargs=${IPCFG}"

done

echo "Control Plane VMs was created"
echo 'Staring Compute nodes VMs'

for VM_NAME in ${!VM_IP_MAP[@]}; do
        echo "Starting compute node ${VM_NAME}"
        govc vm.power -on ${VM_NAME}
done