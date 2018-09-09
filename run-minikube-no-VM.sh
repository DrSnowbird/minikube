#!/bin/bash

# ---- References: ----
# https://github.com/kubernetes/minikube

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

WITH_VM=0
RE_INSTALL_MINIKUBE=1
./run-minikube-with-or-without-VM.sh ${WITH_VM} ${RE_INSTALL_MINIKUBE}

