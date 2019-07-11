# How to deploy the system services

Following, are the instructions to deploy the `cert-manager` and the `nginx-ingress` controller.

All commands below should be run from the system folder.

## Prerequisites

* [Helm client and Tiller](https://docs.microsoft.com/en-us/azure/aks/kubernetes-helm)

## Adjust public IPs and hostnames

Make sure to

* Set the correct public static IP (previously allocated with Terraform) in *nginx-ingress-custom.yml*

* Set the correct virtual host names in *nginx-ingress-rules.yml*

## Deploy the cert-manager

> **Warning:** If the first command generates a validation error, you should update the *kubectl* client.

```shell
# Install the CustomResourceDefinition resources separately
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml

# Create the namespace for cert-manager
kubectl create namespace cert-manager

# Label the cert-manager namespace to disable resource validation
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm install \
  --name cert-manager \
  --namespace cert-manager \
  --version v0.8.0 \
  jetstack/cert-manager
```

## Apply cert manager issuers

```shell
kubectl apply -f cert-manager-issuers.yml
```

## Copy letsencrypt secrets from the old deployment (if any)

```shell
kubectl get secrets letsencrypt-staging -o yaml -n=kube-system > letsencrypt-staging.yaml
kubectl apply -f letsencrypt-staging.yaml

kubectl get secrets letsencrypt-prod  -o yaml -n=kube-system > letsencrypt-prod.yaml
kubectl apply -f letsencrypt-prod.yaml
```

## Deploy the ingress controller

Create a name space for `nxignx-ingress`:

```shell
kubectl create namespace ingress
```

```shell
helm install stable/nginx-ingress \
    --namespace ingress \
    -n nginx-ingress \
    -f nginx-ingress-custom.yml \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```

## Apply the ingress rules

```shell
kubectl apply -f nginx-ingress-rules.yml
```

## Create cluster admin role

```shell
kubectl apply -f cluster-admin.yml
```

## Storage and data persistence

By default Azure uses two storage classes to provide data persistence functionalities: *default* and *managed-premium*. These are automatically configured by Azure at setup time. By default, both classes do not support dynamic storage dimensions upgrades and their reclaim policy is set to Delete, which would cause data to be deleted when a persistent volume (so a chart) gets deleted.

### Deploy Azure Disk custom Storage Class

The Azure disk custom storage class implements all the features provided by both default storage classes, but also enable dynamic storage upgrades and set the reclaim policy to Retain.

To deploy the custom storage class:

```shell
kubectl apply -f azure-disk-sc-custom.yaml
```

>Note: The limitation of the disk type storage classes is that disks can be attached only to one pod at the time.

### Deploy Azure Files Storage Class and related role-based access control (RBAC)

The Azure Files storage class is an additional storage class. It's slower than the Azure disk storage classes mentioned above but it can be sometimes useful when multiple containers need to access the same disk and share files.
Since some services may take advantage of it, it's strongly suggested to load its drivers in the cluster. To load the Azure file storage class:

```shell
kubectl apply -f azure-file-sc.yaml
```

In order to be able to use the Azure files storage class, both a ClusterRole and a ClusterRoleBinding need to be created. To do so, run:

```shell
kubectl apply -f azure-pvc-roles.yaml
```
