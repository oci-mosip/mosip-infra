#!/bin/sh
# Installs all idp helm charts
## Usage: ./install.sh [kubeconfig]

if [ $# -ge 1 ] ; then
  export KUBECONFIG=$1
fi

NS=idp
CHART_VERSION=12.0.2

echo Create $NS namespace
kubectl create ns $NS

echo Istio label
kubectl label ns $NS istio-injection=enabled --overwrite
helm repo update

echo Copy configmaps
./copy_cm.sh

IDP_HOST=$(kubectl get cm global -o jsonpath={.data.mosip-idp-host})

echo "Create configmaps idp-ui-cm, delete if exists"
kubectl -n $NS delete --ignore-not-found=true configmap idp-ui-cm
kubectl -n $NS create configmap idp-ui-cm --from-literal="REACT_APP_API_BASE_URL=http://$IDP_HOST/v1/idp" --from-literal="REACT_APP_SBI_DOMAIN_URI=http://$IDP_HOST"

echo "Create configmaps mockida, delete if exists"
kubectl -n $NS  --ignore-not-found=true delete cm mock-auth-data
kubectl -n $NS create cm mock-auth-data --from-file=./mock-auth-data/

echo Installing idp
helm -n $NS install idp mosip/idp-ui --version $CHART_VERSION

echo Installing IDP UI
helm -n $NS install idp-ui mosip/idp-ui --set istio.hosts\[0\]=$IDP_HOST --version $CHART_VERSION

kubectl -n $NS  get deploy -o name |  xargs -n1 -t  kubectl -n $NS rollout status

echo Installed IDP service & IDP-UI
