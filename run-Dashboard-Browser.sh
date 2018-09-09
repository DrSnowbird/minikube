#!/bin/bash -x

# reference: https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/#deploying-the-dashboard-ui

# How to access Dashboard of Kubernete?

echo "## ... 1.) see kube-system pod .........."
kubectl get pods --namespace=kube-system

echo "## ... 2.) see kube-system svc .........."
kubectl get svc --namespace=kube-system|

echo "## ... 3.) find Dashboard UI web port  .........."

DASHBOARD_PORT=`kubectl get svc --namespace=kube-system|grep 'kubernetes-dashboard' | cut -d':' -f2 | cut -d'/' -f1 `
echo "DASHBOARD_PORT=${DASHBOARD_PORT:-30000}"

echo "## ... 4.) launch your Firefox or Chrome  .........."
# /usr/bin/google-chrome http://127.0.0.1:30000/

if `which google-chrome`; then
    /usr/bin/google-chrome http://192.168.99.100:${DASHBOARD_PORT}/ &
else
    firefox http://192.168.99.100:${DASHBOARD_PORT}/ &
fi

