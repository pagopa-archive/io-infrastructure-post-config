# How to deploy the system services

Following, are the instructions to deploy the components needed to provide basic system functionalities.

Some of these components are distributed as single *yaml* files, others get installed using *helm*.

All commands below should be run from the system folder.

## Prerequisites

* [Kubectl CLI](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

* [Helm client and Tiller](https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm)

## Adjust public IPs and hostnames

Make sure to

* Set the correct public static IP (previously allocated with Terraform) in *istio-custom.yaml*

* Set the correct public static IP (previously allocated with Terraform) in *nginx-ingress-custom.yaml*

If any change is needed, please commit it to the repository.

## Deploy the cert-manager

> **Warning:** If the first command generates a validation error, you should update the *kubectl* client.

```shell
# Install the CustomResourceDefinition resources separately
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml

# Create the namespace for cert-manager
kubectl create namespace cert-manager

# Label the cert-manager namespace to disable resource validation
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Add the Jetstack Helm repository and download the repo index
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install the cert-manager Helm chart
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.8.0 \
  jetstack/cert-manager
```

## Apply cert-manager issuers

```shell
kubectl apply -f cert-manager-issuers.yaml
```

## Deploy Istio

Istio is used for multiple purposes, primarily to establish encrypted tunnels with third party services.

It's important that Istio gets installed as the first gateway component, so that the cluster outgoing traffic will be natted with the same IP of the Istio ingress gateway. This will make easier to establish peer-to-peer communications with third parties, where -usually- both a source and a destination IP are requested.

To install Istio

```shell
# Add locally the Istio helm repository and download the repo index
helm repo add istio.io https://storage.googleapis.com/istio-release/releases/1.2.2/charts/
helm repo update

# Create Istio namespace
kubectl create namespace istio-system

# Install Istio CRDs
helm install istio.io/istio-init --name istio-init --namespace istio-system

# Wait until Istio CRDs are equal to 23.
kubectl get crds | grep 'istio.io' | wc -l

# Install Istio
helm install istio.io/istio \
  --name istio \
  --namespace istio-system \
  -f istio-custom.yaml
```

## Deploy the Nginx ingress controller

Create a namespace for `nginx-ingress`:

```shell
kubectl create namespace ingress
```

```shell
helm install stable/nginx-ingress \
    --namespace ingress \
    -n nginx-ingress \
    -f nginx-ingress-custom.yaml
```

## Storage and data persistence

By default, Azure uses two storage classes to provide data persistence functionalities: *default* and *managed-premium*. These are automatically configured by Azure at setup time. Both classes do not support dynamic storage resize, and their reclaim policy is set to Delete, which would cause data to be deleted when a persistent volume (so a chart) gets deleted.

### Deploy Azure Disk custom Storage Class

The Azure disk custom storage class implements all the features provided by both default storage classes, and it also enables dynamic storage upgrades and sets the reclaim policy to retain.

To deploy the custom storage class:

```shell
kubectl apply -f azure-disk-sc-custom.yaml
```

>Note: A current limitation of disk type storage classes is that disks can be attached to one pod at the time.

### Deploy Azure Files Storage Class and related role-based access control (RBAC)

The Azure Files storage class is an additional storage class. It's slower than the Azure disk storage classes mentioned above but it can sometimes be useful when multiple containers need to access the same disk and share files.
Since some services may take advantage of it, it's strongly suggested to load its drivers in the cluster. To load the Azure file storage class:

```shell
kubectl apply -f azure-file-sc.yaml
```

In order to be able to use the Azure files storage class, both a ClusterRole and a ClusterRoleBinding need to be created. To do so, run

```shell
kubectl apply -f azure-pvc-roles.yaml
```
