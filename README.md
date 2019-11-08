# IO (Digital Citizenship) infrastructure post configuration scripts

The repository contains the Kubernetes configurations used to configure IO resources after they've been instantiated with [Terraform](https://github.com/teamdigitale/io-infrastructure-live).

## What is IO?

More informations about the IO can be found on the [Digital Transformation Team website](https://teamdigitale.governo.it/en/projects/digital-citizenship.htm)

## Tools references

The repository makes mainly use of the following tools:

* [Kubernetes](https://kubernetes.io/)
* [Helm](https://helm.sh/)

## How to use this repository and its tools

The repository is a collection of scripts to run in the IO infrastructure to configure various types of resources (i.e. VMs, containers, ...), previously provisioned using some [Terraform scripts](https://github.com/teamdigitale/io-infrastructure-live).

To configure the IO infrastructure you should have full access to it with administrative privileges.

## Folder structure

Each folder generally represents an IO service, except a few of them that instead realize specific functions:

* **system** - contains system services (look at the *deploy system services* paragraph below)

* **storage** - contains the PersistentVolumeClaim configurations (PVCs) used by some of the applications to work. Inside, each PVC configuration is named as the chart that makes use of it

* **configs** - helm configuration value files that extend the basic helm charts default values. Each file generally represents a deployment environment (i.e. dev, prod, ...)

# Deploy Kubernetes Resources

This readme explains how deploy and manage Kubernetes resources for the IO project.

## Prerequisites

1. Ask your System Administrator for a personal Azure account to access the existing deployment
2. Install the [Azure CLI tool](https://github.com/Azure/azure-cli). Once installed, try to login with `az login`. A web page will be displayed. Once the process completes you should be able to use the az tool and continue
3. Install and setup [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
4. Install and setup the [helm client](https://helm.sh/docs/using_helm/#installing-helm)
5. Make sure you're on the correct azure subscription (`az account set -s YOUR-SUBSCRIPTION`)

>NOTE: You can either ask your subscription id to your administrator or view it online from [portal.azure.com](portal.azure.com).

6. Download the K8S cluster configuration: if you're a user of an already existing cluster download the credentials with your own Azure username: `az aks get-credentials -n AKS_CLUSTER_NAME -g RESOURCE_GROUP`. Otherwise, if you've just provisioned the k8s cluster and it's the very first time you are accessing it, download the credentials using the admin credentials: `az aks get-credentials -n AKS_CLUSTER_NAME -g RESOURCE_GROUP --admin`); then, proceed to the next section .

>NOTE: You can either ask your resource group and AKS cluster name to your administrator or view it online at [portal.azure.com](portal.azure.com).

7. You may have more than one cluster configuration on your computer.

* To see your contexts: `kubectl config get-contexts`
* To use your context: `kubectl config user-context CONTEXT_NAME`

  More info [here](https://kubernetes-v1-4.github.io/docs/user-guide/kubectl/kubectl_config_use-context/)

8. At this point you should be able to see the available PODs on the cluster, if any: `kubectl get pods`, and the helm deployments, if any and if helm is installed (`helm ls`). See further instructions below if it's not.

>NOTE: Your helm client may not be in sync with the Tiller version installed on the server. In these case you can run *helm init --upgrade* to synchronize the two versions.

## Deploy system services

Following, are the instructions to deploy the system services needed by all IO applications to work.

> **WARNING:** The following commands should be generally run once, while setting up the cluster the first time. Make sure this is your case before proceeding. If you run them anyway, nothing bad should happen, since all of them should be idempotent.

### Storage and data persistence

By default Azure uses two *storage classes* to provide data persistence functionalities: *default* and *managed-premium*. These are automatically configured by Azure at setup time. By default, both classes do not support dynamic storage resizes, and their reclaim policy is set to *Delete*, which would cause data to be deleted when a persistent volume claim gets deleted.

#### Deploy the Azure Disk custom Storage Class

The *Azure disk custom storage class* implements all the features provided by both default storage classes, while also enabling dynamic storage resizes and setting the reclaim policy to *Retain*, thus preserving managed disks, even when a PVC gets deleted.

To deploy the custom storage class, run:

```shell
kubectl apply -f system/azure-disk-sc-custom.yaml
```

>Note: The limitation of disk type storage classes is that disks can be attached only to one pod at the time.

#### Deploy Azure Files Storage Class and related role-based access control (RBAC)

The Azure Files storage class is slower than the Azure disk storage classes mentioned above but it can be sometimes useful when multiple containers need to access the same disk and share files.
Since some services may take advantage of it, it's strongly suggested to load its drivers in the cluster.

To load the Azure file storage class, run:

```shell
kubectl apply -f system/azure-file-sc.yaml
```

In order to be able to use the Azure files storage class, both a ClusterRole and a ClusterRoleBinding need to be created.

To do so, from the *system* folder run:

```shell
kubectl apply -f azure-pvc-roles.yaml
```

### Install tiller: the server-side component of helm

Tiller (the server-side component of helm) is required to install any other component.

To install *tiller* run:

```shell
helm init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade
```

### Enable synchronization of Azure Keyvault secrets with Kubernetes secrets

It's strongly recommended to make Kubernetes retrieve secrets from the Azure Keyvault, instead of manually creating and editing secrets directly in Kubernetes. This approach is safer and allows an easier maintenance of the Kubernetes cluster.

The secrets synchronization and container injection is realized using [this component](https://github.com/SparebankenVest/azure-key-vault-to-kubernetes).

Add the *spv-charts* repo and update the repo index:

```shell
helm repo add spv-charts http://charts.spvapi.no
helm repo update
```

Installation:

```shell
helm install spv-charts/azure-key-vault-env-injector \
    -n key-vault-env-injector \
    --set installCrd=false

helm install spv-charts/azure-key-vault-controller \
    -n key-vault-controller
```

Enable the automatic env variables injection for all containers in the default namespace:

```shell
kubectl apply -f system/azure-key-vault.yaml
```

Each chart already contains an *azure-key-vault-secrets.yaml* file that creates

* A Kubernetes empty secret

* AzureKeyVaultSecret objects that trigger the pull of the secrets from the Azure Keyvault, synchronize the value with the local Kubernetes secret, and inject them as environment variables in the chart containers as needed

* Moreover, environment variables are imported in the *deployment.yaml* files with the value format `name-of-the-variable@azurekeyvault`

### Deploy the cert-manager

The cert-manager is a Kubernetes component that takes care of adding and renewing TLS certificates for any virtual host specified in the ingress, through the integration with some providers (i.e. letsencrypt) .

> **Warning:** If the first command generates a validation error, you should update the *kubectl* client.

To deploy the cert-manager follow the helm installation instructions from the [official website](https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html#steps).

### Apply cert-manager issuers

To integrate the cert-manager with the *letsencrypt certificate issuer*, run:

```shell
kubectl apply -f system/cert-manager-issuers.yaml
```

### Deploy the ingress controller

The nginx ingress controller works as a reverse proxy, routing requests from the Internet to the IO applications living in the cluster. All applications DNS names are resolved to a single, public static IP address, that must be pre-provisioned on Azure.
Before proceeding, make sure you have allocated the public, static IP address using Terraform, and that the same address is reflected in the `nginx-ingress-custom.yaml` file.

Then, create a name space for the `nxignx-ingress`:

```shell
kubectl create namespace ingress
```

And install the ingress itself:

```shell
helm install stable/nginx-ingress \
    --namespace ingress \
    -n io-ingress \
    -f system/nginx-ingress-custom.yaml \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```

## Deploy Azure Storage PersistentVolumeClaim (PVCs) for IO services

PVCs for IO services are defined outside the helm-charts to avoid their deletion, while a chart gets removed for maintenance, or simply for human errors.
PVC definitions can be found in the *storage* folder. Each PVC is prefixed with the name of the chart that makes use of it, and should be created before installing the corresponding chart.

To create a PVC for a service, run

```shell
kubectl apply -f storage/SERVICE_NAME.yaml
```

PVCs can also be addded all at once, running

```shell
kubectl apply -f storage
```

## Deploy generic resources and services

IO services are packaged using helm charts.
Each helm chart configures one or more of the following services:

* Deployments

* Services and load balancers

* Nginx ingress rules (if any)

* Certificate requests (if any)

To list existing deployments

```shell
helm ls
```

To deploy an IO service

```shell
helm install [-f configs/CONFIG_NAME.yaml] [-n DEPLOYMENT_NAME] {NAME_OF_YOUR_CHART}
```

Where:

* CONFIG_NAME is optional and it's one of the configurations in the configs folder. By default, the *development* environment configuration is applied by default. So, for *dev* environments no configurations should be specified.

* DEPLOYMENT_NAME is optional, but strongly suggested. It represents an arbitrary name to give to the deployment (names can then be listed with `helm ls`, and used to reference charts in other helm commands)

* NAME_OF_YOUR_CHART is mandatory and corresponds to one of the folder names, each one representing the chart.

For example

```shell
helm install -n app-backend app-backend
```

Or, to deploy the same app-backend app, applying the production configuration

```shell
helm install -f configs/prod.yaml -n app-backend app-backend
```

To remove an existing IO service

```shell
helm delete --purge [DEPLOYMENT_NAME]
```

### Kubernetes secrets

The majority of the charts need some secrets to be populated in the Azure Keyvault, before being deployed. These secrets need to have a specific name that matches what's defined in the chart. Refer to the chart value files and readmes to know what secrets need to be defined before installing the chart.

Secrets usually are in the format: *k8s-chart_name-secret-secret_name*.

### The special case of pagopa-proxy

*pagopa-proxy* needs to be deployed in a very specific way. For more info on its deployment, take a look at the [pagopa-proxy readme](pagopa-proxy/README.md).

## How to contribute

Contributions are welcome. Feel free to open issues and submit [pull requests](./pulls) at any time, but please read [our handbook](https://github.com/teamdigitale/io-handbook) first.

## License

Copyright (c) 2019 Presidenza del Consiglio dei Ministri

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.
