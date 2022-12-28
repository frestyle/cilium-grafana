#!/bin/bash

export CILIUM_V=${1:-1.12.2}
export INGRESS_V=${1:-4.1.3}
export KIND_CLUSTER_NAME="${KIND_CLUSTER_NAME:-cilium}"
export METALLB_V=${1:-0.13.7}

# create registry container unless it already exists
reg_name='kind-registry'
reg_port='5000'

kind delete cluster --name "${KIND_CLUSTER_NAME}"


kind create cluster --name "${KIND_CLUSTER_NAME}" --config kind-config.yaml 


# helm repo add cilium https://helm.cilium.io
# helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
# helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
# helm repo add minio https://operator.min.io
# helm repo add grafana https://grafana.github.io/helm-charts
# helm repo add strimzi https://strimzi.io/charts
# helm repo add elastic https://helm.elastic.co


# connect the registry to the cluster network
# (the network may already be connected)
docker network connect "kind" "${reg_name}" || true


# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF



helm template kube-prometheus prometheus-community/kube-prometheus-stack --include-crds \
  | yq 'select(.kind == "CustomResourceDefinition") * {"metadata": {"annotations": {"meta.helm.sh/release-name": "kube-prometheus", "meta.helm.sh/release-namespace": "monitoring"}}}' \
  | kubectl create -f -


kubectl create ns monitoring

docker pull quay.io/cilium/cilium:"v$CILIUM_V"
kind load docker-image quay.io/cilium/cilium:"v$CILIUM_V"


# masterIP is needed for kubeProxyReplacement
MASTER_IP="$(docker inspect "${KIND_CLUSTER_NAME}"-control-plane | jq '.[0].NetworkSettings.Networks.kind.IPAddress' -r)"
helm install --namespace kube-system cilium cilium/cilium \
    --version "v$CILIUM_V"  \
    --wait \
    --set cluster.id=0 \
    --set cluster.name="$KIND_CLUSTER_NAME" \
    --set encryption.nodeEncryption=false\
    --set ipam.mode=kubernetes\
    --set kubeProxyReplacement=strict\
    --set serviceAccounts.cilium.name=cilium\
    --set serviceAccounts.operator.name=cilium-operator\
    --set tunnel=vxlan \
    --set hubble.enabled=true \
    --set hubble.metrics.enabled="{dns,drop,tcp,flow,icmp,http}"  \
    --set hubble.relay.enabled=true \
    --set hubble.relay.prometheus.enabled=true \
    --set prometheus.enabled=true \
    --set operator.replicas=1\
    --set operator.prometheus.enabled=true \
    --set k8sServiceHost="${MASTER_IP}" \
    --set k8sServicePort=6443


# setup ingress controller 
helm upgrade ingress-nginx ingress-nginx/ingress-nginx \
  --install \
  --namespace ingress-nginx --create-namespace \
  --version "$INGRESS_V" \
  --set rbac.create=true  \
  --set controller.metrics.enabled=true \
  --set-string controller.podAnnotations."prometheus\.io/scrape"="true" \
  --set-string controller.podAnnotations."prometheus\.io/port"="10254"  \
  --set controller.service.externalTrafficPolicy=Local  \
  --values config/ingress-nginx-values.yaml


kubectl -n ingress-nginx apply -f  config/ingress-nginx-values.yaml

# Prometheus & Grafana install
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/v1.12/examples/kubernetes/addons/prometheus/monitoring-example.yaml


kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v$METALLB_V/config/manifests/metallb-native.yaml

# On first install only
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

# wait for controller creation before crd install 
kubectl -n metallb-system wait -l "app=metallb" --for=condition=ready pod --timeout=-1s

kubectl apply  -f config/metallb-system.yaml


helm upgrade cilium cilium/cilium --version "$CILIUM_V" \
   --namespace kube-system \
   --reuse-values \
   --set hubble.relay.enabled=true \
   --set hubble.ui.enabled=true
