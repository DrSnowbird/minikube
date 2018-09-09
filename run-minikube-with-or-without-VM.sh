#!/bin/bash -x

#### ---- Usage ----
function usage() {
    echo "--------------------------------------------------------------------------------"
    echo "Usage: $(basename $0) [<Wiht_VM_or_NOT> [<re-install_or_not> ] ]"
    echo "  <Wiht_VM_or_NOT: default=0 (NO VM, e.g. VirtualBox, etc.)>"
    echo "  <re-install_or_not>: default 1 (Not to re-install) "
    echo "--------------------------------------------------------------------------------"
}
# ---- References: ----
# https://github.com/kubernetes/minikube

WITH_VM=${1:-1}
RE_INSTALL_MINIKUBE=${2:-1}

## -- With VM Driver
## List of VM Drivers:
## virtualbox
##    vmwarefusion
##    KVM2
##    KVM (deprecated in favor of KVM2)
##    hyperkit
##    xhyve
##    hyperv
##    none
##
VM_DRIVER=VirtualBox

###############################################
#### ---- Replace Key-Value pair in a file ----
###############################################
function replaceKeyValue() {
    if [ $# -lt 3 ]; then
        echo "ERROR: --- Usage: $0 <config_file> <key> <value> [<delimiter>] [<prefix-pattern>]"
        echo "e.g."
        echo './replaceKeyValue.sh \"elasticsearch.yml\" \"^network.host\" \"172.20.1.92\" \":\" \"# network\" '
        exit 1
    fi

    CONFIG_FILE=${1}
    TARGET_KEY=${2}
    REPLACEMENT_VALUE=${3}
    DELIMITER_TOKEN=${4:-:}
    PREFIX_PATTERN=${5:-}

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "*** ERROR $CONFIG_FILE: Not found!"
        exit 1
    fi

    if grep -q "${TARGET_KEY} *${DELIMITER_TOKEN}" ${CONFIG_FILE}; then   
        #sudo sed -c -i "s/\($TARGET_KEY *= *\).*/\1$REPLACEMENT_VALUE/" $CONFIG_FILE
        sudo sed -i "s/\(${TARGET_KEY} *${DELIMITER_TOKEN} *\).*/\1${REPLACEMENT_VALUE}/" ${CONFIG_FILE}
    else
        if [ "$PREFIX_PATTERN" == "" ]; then
            #echo "$TARGET_KEY= $REPLACEMENT_VALUE" | sudo tee -a $CONFIG_FILE
            echo "${TARGET_KEY}${DELIMITER_TOKEN} ${REPLACEMENT_VALUE}" | sudo tee -a ${CONFIG_FILE}
        else
            sudo sed -i "/${PREFIX_PATTERN}/a \
                ${TARGET_KEY}${DELIMITER_TOKEN} ${REPLACEMENT_VALUE}" ${CONFIG_FILE}
        fi
    fi
}

# ------------- How to overcome issue with without VM Support -------------
#   https://github.com/kubernetes/minikube/issues/2575
# see: https://raw.githubusercontent.com/robertluwang/docker-hands-on-guide/master/minikube-none.sh
# The workaround was not to specify a bridge IP for docker, as I had thought. Instead you need to start minikube like so:
# 
# minikube start--vm-driver=none --apiserver-ips 127.0.0.1 --apiserver-name localhost
#
# And then go and edit ~/.kube/config, replacing the server IP that was detected from the main network interface with 
# "localhost". For example, mine now looks like this:
# 
# - cluster:
#     certificate-authority: /home/jfeasel/.minikube/ca.crt
#     server: https://localhost:8443
#   name: minikube
# With this configuration, I can access my local cluster all of the time, even if the main network interface is disabled.
# 
# Also, we should note that it is required to have "socat" installed on the Linux environment. See this issue for details: 
# kubernetes/kubernetes#19765 I saw this when I tried to use helm to connect to my local cluster; I got errors with port-
# forwarding. Since I'm using Ubuntu all I had to do was sudo apt-get install socat and then everything worked as expected.

# -----------------------------------------------------------------
# Linux Continuous Integration without VM Support
# Example with kubectl installation:


MINIKUBE_URL=https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
INSTALL_DIR=/usr/local/bin
function installMinikube() {
    date
    echo
    echo "installMinikube(): ... check minikube binary ..."
    if [ -f ${INSTALL_DIR}/minikube ]; then
        echo "installMinikube(): ... minikube existing, change to minikube.old"
        sudo mv ${INSTALL_DIR}/minikube ${INSTALL_DIR}/minikube.old
    fi

    if [ -f ${INSTALL_DIR}/kubectl ]; then
        echo "installMinikube(): ... kubectl existing, change to kubectl.old"
        sudo mv ${INSTALL_DIR}/kubectl ${INSTALL_DIR}/kubectl.old
    fi

    if [ -f ${INSTALL_DIR}/localkube ]; then
        echo "installMinikube(): ... localkube existing, change to localkube.old"
        sudo mv ${INSTALL_DIR}/localkube ${INSTALL_DIR}/localkube.old
    fi

    echo
    echo "installMinikube(): ... Install minikube ..."
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
        && chmod +x minikube && sudo mv minikube ${INSTALL_DIR}

    echo 
    echo "installMinikube(): ... Install kubectl ..."
    curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
        && chmod +x kubectl \
        && sudo cp kubectl ${INSTALL_DIR}/

    curl -Lo kubectl https://storage.googleapis.com/kubernetes-release/release/\
    $(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
        && chmod +x kubectl \
        && sudo mv kubectl ${INSTALL_DIR}

}
if [ $RE_INSTALL_MINIKUBE -ge 1 ]; then
    installMinikube
fi

# ------ kube config file ------

export MINIKUBE_WANTUPDATENOTIFICATION=false
export MINIKUBE_WANTREPORTERRORPROMPT=false
export MINIKUBE_HOME=$HOME
export CHANGE_MINIKUBE_NONE_USER=true
export PATH="`pwd`/":$PATH

#### Setup new ./kube directory and Clean up old residues of minikue machines ####
function setupKubeLocalDirectory() {
    echo "setupKubeLocalDirectory(): ... Setup new ./kube directory and Clean up old residues of minikue machines"
    sudo rm -rf $HOME/.kube 
    sudo rm -rf $HOME/.minikube/
    mkdir $HOME/.kube
    touch $HOME/.kube/config
    export KUBECONFIG=$HOME/.kube/config
}
setupKubeLocalDirectory

## ---- Wait for kube to come up ----
function waitForKubeUp() {
    # this for loop waits until kubectl can access the api server that Minikube has created
    for i in {1..100}; do # timeout for 180 minutes
       sudo kubectl get po > /dev/null
       if [ $? -ne 1 ]; then
          echo "waitForKubeUp(): ... possible some errors .... to see whether k8s_xxx containers showing up..."
          break
      fi
      echo "waitForKubeUp(): ... sleep 10"
      sleep 5
    done
}


## ---- Start kube ----
if [ ${WITH_VM} -eq 1 ]; then
    ## -- With VM Driver
    ## VirtualBox or KVM or none
    VM_DRIVER=`echo "${VM_DRIVER}" | tr '[:upper:]' '[:lower:]'`
    #sudo minikube start --vm-driver=${VM_DRIVER}
    minikube start --extra-config=apiserver.v=4 --bootstrapper=localkube
    #minikube start --kubernetes-version="v1.10.0" --extra-config=apiserver.v=4 --bootstrapper=localkube
    waitForKubeUp
else
    ## ****************************************************************************************
    ## **** WARNING: IT IS NOT RECOMMENDED TO RUN THE "none" DRIVER ON PERSONAL WORKSTATIONS!!
    ## **** WARNING: The 'none' driver will run an insecure kubernetes apiserver as root that 
    ## **** WARNING: may leave the host vulnerable to CSRF attacks
    ## ****************************************************************************************
    #VM_DRIVER=none
    #BRIDGE_SERVER_IP="`cat $HOME/.kube/config | grep server | grep 'localhost:8443' `"
    #if [ "${BRIDGE_SERVER_IP}" == "" ]; then
    #   sudo -E minikube start --vm-driver=none
    #   waitForKubeUp
    #   sudo -E minikube stop
    #   sleep 10
    #   ## -- Need to replace "Bridge IP=address to localhost 127.0.0.1"
    #   ## -- (see https://github.com/kubernetes/minikube/issues/2575)
    #   cp --backup=numbered $HOME/.kube/config $HOME/.kube/
    #   replaceKeyValue "$HOME/.kube/config" "server" "https\:\/\/localhost\:8443"
    #   sudo -E minikube start --vm-driver=none --apiserver-ips 127.0.0.1 --apiserver-name localhost
    #else
    #   sudo -E minikube start --vm-driver=none --apiserver-ips 127.0.0.1 --apiserver-name localhost
    #   waitForKubeUp
    #fi
    #sudo -E minikube start --vm-driver=none
    sudo -E minikube start --vm-driver=none --apiserver-ips 127.0.0.1 --apiserver-name localhost
    sudo -E minikube start --vm-driver=none --kubernetes-version="v1.10.0" --extra-config=apiserver.v=4 --bootstrapper=localkube
    sudo -E minikube start --kubernetes-version="v1.10.0" --vm-driver=kvm2 --extra-config=apiserver.v=4 --bootstrapper=localkube
    waitForKubeUp

    ## localkube (not needed!)
    sudo chmod +x ${INSTALL_DIR}/localkube
fi

echo 
date
echo "+++++++++++++++ minikube installation done +++++++++++++++++++"


# kubectl commands are now able to interact with Minikube cluster

#  Starting local Kubernetes v1.10.0 cluster...
#  Starting VM...
#  Getting VM IP address...
#  Moving files into cluster...
#  Setting up certs...
#  Connecting to cluster...
#  Setting up kubeconfig...
#  Starting cluster components...
#  Kubectl is now configured to use the cluster.
#  ===================
#  WARNING: IT IS RECOMMENDED NOT TO RUN THE NONE DRIVER ON PERSONAL WORKSTATIONS
#      The 'none' driver will run an insecure kubernetes apiserver as root that may leave the host vulnerable to CSRF attacks

## Ref: https://github.com/robertluwang/docker-hands-on-guide/blob/master/minikube-none-installation.md
#May get this error when run sript,

#bash ./minikube-none.sh                  
#sudo: minikube: command not found
#usually we put minikube/kubectl/localkube at /usr/local/bin, but /usr/local/bin is not in sudo secure_path.

#so update secure_path in sudo config,
#$ sudo visudo
#Defaults    secure_path = /sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin

