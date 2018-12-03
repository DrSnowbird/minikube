#!/bin/bash -x
sudo rm -rf ~/.minikube*
sudo rm -rf ~/.kube/config
minikube start --vm-driver=virtualbox


