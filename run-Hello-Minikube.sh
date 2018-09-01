#!/bin/bash -x

#minikube start

kubectl run hello-minikube --image=k8s.gcr.io/echoserver:1.4 --port=8080

kubectl expose deployment hello-minikube --type=NodePort

# We have now launched an echoserver pod but we have to wait until the pod is up before curling/accessing it
# via the exposed service.
# To check whether the pod is up and running we can use the following:
kubectl get pod

# We can see that the pod is still being created from the ContainerCreating status
kubectl get pod

# We can see that the pod is now Running and we will now be able to curl it:
curl $(minikube service hello-minikube --url)

kubectl delete service hello-minikube

kubectl delete deployment hello-minikube

minikube stop
