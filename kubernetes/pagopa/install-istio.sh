#!/usr/bin/env bash

# Istio installation - start

# Add locally the Istio helm repository and download repo index
helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.2.2/charts/
helm repo update

# Create Istio namespace
kubectl create namespace istio-system || true

# Install Istio CRDs
helm install istio.io/istio-init --name istio-init --namespace istio-system || true

# Wait until Istio CRDs are equal to 23.
while [ $(kubectl get crds | grep 'istio.io' | wc -l) -ne 23 ]
do
  echo Istio CRDs should be 23. Waiting for Istio CRDs to be created...
done
echo Istio CRDs successfully created. Moving on.

# Install Istio using the default profile (more options at https://istio.io/docs/setup/kubernetes/install/helm/)

helm install istio.io/istio \
  --name istio \
  --namespace istio-system \
  --set 'gateways.istio-ingressgateway.loadBalancerIP'='13.80.16.80' \
  --set 'gateways.istio-egressgateway.enabled'=true \
  --set 'gateways.istio-egressgateway.secretVolumes[0].name'=nginx-client-certs \
  --set 'gateways.istio-egressgateway.secretVolumes[0].secretName'=nginx-client-certs \
  --set 'gateways.istio-egressgateway.secretVolumes[0].mountPath'=/etc/nginx-client-certs \
  --set 'gateways.istio-egressgateway.secretVolumes[1].name'=nginx-ca-certs \
  --set 'gateways.istio-egressgateway.secretVolumes[1].secretName'=nginx-ca-certs \
  --set 'gateways.istio-egressgateway.secretVolumes[1].mountPath'=/etc/nginx-ca-certs \
  || true

# Istio installation - end
