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

# Deploy Kubernetes Resources

This readme explains how deploy and manage Kubernetes resources for the IO project.

## Prerequisites

1. Ask your System Administrator for a personal Azure account to access the existing deployment
2. Install the [Azure CLI tool](https://github.com/Azure/azure-cli). Once installed, try to login with `az login`. A web page will be displayed. Once the process completes you should be able to use the az tool and continue
3. Install and setup [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
4. Install and setup the [helm client](https://helm.sh/docs/using_helm/#installing-helm)
5. Make sure you're on the correct azure subscription (`az account set -s YOUR-SUBSCRIPTION`)

>NOTE: You can either ask your subscription id to your administrator or view it online from the portal.azure.com page

6. Download the K8S cluster configuration (`az aks get-credentials -n AKS_CLUSTER_NAME -g RESOURCE_GROUP`)

>NOTE: You can either ask your resource group and AKS cluster name to your administrator or view it online from the portal.azure.com page

7. You may have more than one cluster configuration on your computer.

* To see your contexts: `kubectl config get-contexts`
* To use your context: `kubectl config user-context CONTEXT_NAME`

  More info [here](https://kubernetes-v1-4.github.io/docs/user-guide/kubectl/kubectl_config_use-context/)

8. At this point you should be able to see the available PODs on the cluster, if any: `kubectl get pods`, and the helm deployments, if any and if helm is installed (`helm ls`). See further instructions below if it's not.

>NOTE: Your helm client may not be in sync with the Tiller version installed on the server. In these case you can run *helm init --upgrade* to synchronize the two versions.

## Folder structure

The `kubernetes` folder contains a list of sub-folders, each generally representing an IO service.

Few of these folders instead realize specific functions:

* **system** - contains system services (look at the *deploy system services* paragraph below)

* **configs** - helm configuration value files that extend the basic helm charts default values. Each file generally represents a deployment environment (i.e. dev, prod, ...)

## Deploy system services

Following, are the instructions to deploy the system services needed by all IO applications to work.

> **WARNING:** The following commands should be generally run once, while setting up the cluster the first time. Make sure this is your case before proceeding. If you run them anyway, nothing bad should happen, since all of them should be idempotent.

### Storage and data persistence

By default Azure uses two storage classes to provide data persistence functionalities: *default* and *managed-premium*. These are automatically configured by Azure at setup time. By default, both classes do not support dynamic storage dimensions upgrades and their reclaim policy is set to Delete, which would cause data to be deleted when a persistent volume (so a chart) gets deleted.

#### Deploy Azure Disk custom Storage Class

The Azure disk custom storage class implements all the features provided by both default storage classes, but also enable dynamic storage upgrades and set the reclaim policy to Retain.

To deploy the custom storage class, from the *system* folder run:

```shell
kubectl apply -f azure-disk-sc-custom.yaml
```

>Note: The limitation of the disk type storage classes is that disks can be attached only to one pod at the time.

#### Deploy Azure Files Storage Class and related role-based access control (RBAC)

The Azure Files storage class is an additional storage class. It's slower than the Azure disk storage classes mentioned above but it can be sometimes useful when multiple containers need to access the same disk and share files.
Since some services may take advantage of it, it's strongly suggested to load its drivers in the cluster.

To load the Azure file storage class, from the *system* folder run:

```shell
kubectl apply -f azure-file-sc.yaml
```

In order to be able to use the Azure files storage class, both a ClusterRole and a ClusterRoleBinding need to be created.

To do so, from the *system* folder run::

```shell
kubectl apply -f azure-pvc-roles.yaml
```

## Deploy Azure Storage PersistentVolumeClaim (PVCs) for IO services

PVCs for IO services are defined outside the helm-charts to avoid their deletion, while a chart gets removed for maintenance.
PVCs definitions can be found in the *storage* folder, located in the *kubernetes* directory. Each PVC should be created before installing the corresponding chart.

To create a PVC for a service, run

```shell
kubectl apply -f storage/SERVICE_NAME.yaml
```

PVCs can also be addded all at once, running

```shell
kubectl apply -f storage
```

### Install tiller: the server-side component of helm

Tiller is required to install the *cert-manager*, the *nginx-ingress* and all other IO applications.

To install *tiller* run:

```shell
helm init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
helm init --service-account tiller --upgrade
```

### Deploy the cert-manager

The cert-manager is a Kubernetes component that takes care of adding and renewing through the integration with some providers (i.e. letsencrypt) certificates for any virtual host specified in the ingress.

> **Warning:** If the first command generates a validation error, you should update the *kubectl* client.

To deploy the cert-manager follow the helm installation instructions from the [official website](https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html#steps).

### Apply cert-manager issuers

To integrate the cert-manager with the letsencrypt certificate issuer, from the *system* folder run:

```shell
kubectl apply -f cert-manager-issuers.yaml
```

### Deploy the ingress controller

Before proceeding make sure you have created a static, public IP address and that the same address is reflected in the `nginx-ingress-custom.yaml` file.

Create a name space for the `nxignx-ingress`:

```shell
kubectl create namespace ingress
```

```shell
helm install stable/nginx-ingress \
    --namespace ingress \
    -n io-ingress \
    -f nginx-ingress-custom.yaml \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux
```

## Deploy generic resources and services

Generally, IO services are packaged using helm charts.
Each helm chart configures one or more of the following services:

* Deployment

* Services and load balancers

* Nginx ingress rules (if any)

* Certificates (if any)

To list existing deployments

```shell
helm ls
```

To deploy an IO service

```shell
helm install [-f configs/CONFIG_NAME.yaml] [-n DEPLOYMENT_NAME] {NAME_OF_YOUR_CHART}
```

Where:

* CONFIG_NAME is optional and it's one of the configurations in the configs folder

* DEPLOYMENT_NAME is optional. It represents an arbitrary name to give to the deployment (names can then be listed with `helm ls`, and used to reference charts in other helm commands)

* NAME_OF_YOUR_CHART is mandatory and corresponds to one of the folders (each one is a different chart) in the kubernetes directory, besides the special folders reported in the folder structure paragraph, above

For example

```shell
helm install -f configs/dev.yaml -n ckan ckan
```

To remove an existing IO service

```shell
helm delete --purge [DEPLOYMENT_NAME]
```

## How to contribute

Contributions are welcome. Feel free to open issues and submit [pull requests](./pulls) at any time, but please read [our handbook](https://github.com/teamdigitale/io-handbook) first.

## License

Copyright (c) 2019 Presidenza del Consiglio dei Ministri

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.
