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
  --set 'gateways.istio-egressgateway.secretVolumes[0].name'=pagopa-test-client-certs \
  --set 'gateways.istio-egressgateway.secretVolumes[0].secretName'=pagopa-test-client-certs \
  --set 'gateways.istio-egressgateway.secretVolumes[0].mountPath'=/etc/nginx-client-certs \
  --set 'gateways.istio-egressgateway.secretVolumes[1].name'=pagopa-test-root-ca-cert \
  --set 'gateways.istio-egressgateway.secretVolumes[1].secretName'=pagopa-test-root-ca-cert \
  --set 'gateways.istio-egressgateway.secretVolumes[1].mountPath'=/etc/nginx-ca-certs \
  # Comment out the line below if access logs can be enabled
  # --set 'global.proxy.accessLogFile'=/dev/stdout \
  || true

# Istio installation - end

# Certificates

# Client certificate
# 
# kubectl create secret -n istio-system tls pagopa-test-client-certs --key io_private_key.key --cert io_public_certificate.cer

# Downloaded "DigiCert SHA2 Extended Validation Server CA" from https://www.sslsupportdesk.com/digicert-intermediate-cas/
# kubectl create secret -n istio-system generic pagopa-test-root-ca-cert --from-file=ca-chain.cert.pem
