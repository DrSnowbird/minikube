#!/bin/bash -x

minikube start

kubectl run hello-minikube --image=k8s.gcr.io/echoserver:1.4 --port=8080

kubectl expose deployment hello-minikube --type=NodePort

# We have now launched an echoserver pod but we have to wait until the pod is up before curling/accessing it
# via the exposed service.
# To check whether the pod is up and running we can use the following:
kubectl get pod

# We can see that the pod is still being created from the ContainerCreating status
kubectl get pod

echo "..... Wait for 60 seconds for Kubernettes to come up fully ....."
wait 60

# We can see that the pod is now Running and we will now be able to curl it:
curl $(minikube service hello-minikube --url)

echo "--------------------------------------------"
echo "##### Way-4: Ask Yes/No with default Y #####"
echo "--------------------------------------------"
## arg1: "Prompt String, e.g. Enter choice (Y/n) default=Y? "
## arg2: Default value, Y (default) or N
answer=y
function askYesNo() {
    DEFAULT_YES_NO="y"
    if [ $# -lt 2 ]; then
        echo "---- INFO ----: No default choice provided, use Yes/Y as default!"
    fi
    # Prompt and wait for 5 seconds as timeout to accept default value.
    #read -t 5 -n 1 -p "Enter choice (Y/n) default=Y? " answer
    defaultValue=${2:-${DEFAULT_YES_NO}}
    defaultValue=`echo ${defaultValue:0:1}| tr '[:upper:]' '[:lower:]'`
    if [[ ! "nNyY" =~ "${defaultValue}" ]]; then
        defaultValue="${DEFAULT_YES_NO}"
    fi
    #read -t 5 -n 1 -p "$1" answer
    read -n 1 -p "$1" answer
    [ -z "$answer" ] && answer="$defaultValue" 
    answer=`echo ${answer:0:1}| tr '[:upper:]' '[:lower:]'`
    case ${answer:0:1} in
        y|Y )
            echo "===> Yes (you choice $answer)"
        ;;
        n|N )
            echo "===> No (you choice $answer)"
        ;;
        * ) 
            echo "===> Yes (you choice $defaultValue)"
            answer=$defaultValue
        ;;
    esac
}

askYesNo "Continue to DELETE hello-minikube (N/y) default=No/N? " "N"
if [ "$answer" == "y" ]; then
    kubectl delete service hello-minikube
    kubectl delete deployment hello-minikube
fi

askYesNo "Continue to STOP -minikube (N/y) default=No/N? " "N"
if [ "$answer" == "y" ]; then
    minikube stop
fi




