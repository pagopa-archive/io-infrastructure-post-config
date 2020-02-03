# IO (Digital Citizenship) infrastructure post configuration scripts

The repository contains the Kubernetes configurations used to configure IO resources after they've been instantiated with [Terraform](https://github.com/teamdigitale/io-infrastructure-live).

## What is IO?

More informations about the IO can be found on the [Digital Transformation Team website](https://teamdigitale.governo.it/en/projects/digital-citizenship.htm)

## How to use this repository and its tools

The repository contains a collection of Kubernetes configuration files to provision some of the IO services on top of an existing Kubernetes cluster. The guide assumes a repository has been already provisioned using some [Terraform scripts](https://github.com/teamdigitale/io-infrastructure-live).

## Tools references

The repository makes mainly use of the following tools:

* [Kubernetes](https://kubernetes.io/)
* [Helm v2.15.2](https://helm.sh/)

## Folder structure

Each folder generally represents an IO service, except a few of them that instead realize specific functions:

* **system** - contains system services (look at the *deploy system services* paragraph below)

* **storage** - contains the PersistentVolumeClaim configurations (PVCs) used by some of the applications to work. Inside, each PVC configuration is named as the chart that makes use of it

* **configs** - helm configuration value files that extend the basic helm charts default values. Each file generally represents a deployment environment (i.e. dev, prod, ...)

## Prerequisites

These are the tools and configurations you need to interact with a cluster:

* Ask your System Administrator for a personal Azure account to access the existing deployment

* Install the [Azure CLI tool](https://github.com/Azure/azure-cli). Once installed, try to login with `az login`. A web page will be displayed. Once the process completes you should be able to use the az tool and continue

* Install and setup [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

* If you have access to multiple Azure accounts through the az CLI, make sure you're on the correct Azure subscription (`az account set -s YOUR-SUBSCRIPTION`). Then, download the K8S cluster configuration: `az aks get-credentials -n AKS_CLUSTER_NAME -g RESOURCE_GROUP`. The cluster configuration will be automatically downloaded on your local machine and merged with the rest of the kubernetes configurations you already have.

    * To see your contexts: `kubectl config get-contexts`

    * To use your context: `kubectl config user-context CONTEXT_NAME`

More info [here](https://kubernetes-v1-4.github.io/docs/user-guide/kubectl/kubectl_config_use-context/)

>NOTE: You can either ask the subscription id, the resource group and AKS cluster name to your administrator, or view it online at [portal.azure.com](portal.azure.com).

* Install and setup the [helm client](https://helm.sh/docs/using_helm/#installing-helm)

* Ask the Administrator for certificates to access the helm installation. To simplify the helm commands run time by time, you can copy the CA certificate, the client private key and the client certificate to a specific location, so they're automatically added:

>NOTE: Although this is quite inconvenient, you'll still have the option to manually specify where the certificates are located at each helm call.

* You're ready to go! Depending on the permissions you have, you should be able to see the available resources on the cluster, if any: `kubectl get pods [-n NAMESPACE]`, and the helm deployments (`helm ls`)

### Helm deep-dive

Helm client-side for IO setup deserves a special mention.

Once the cluster is setup to use a dedicated namespace for Tiller, certificates and only establish TLS connections, you'll need to run each helm command in the following way:

```shell
helm ls --tiller namespace --tls --tls-cert PATH_TO_CLIENT_CERT --tls-key PATH_TO_CLIENT_KEY --tls-ca-cert PATH_TO_CA_CERT
```

Life can be easier than that! You may simply choose to copy the three files required in the default helm configuration directory (~/.helm):

```shell
$ cp ca.cert.pem $(helm home)/ca.pem
$ cp helm.cert.pem $(helm home)/cert.pem
$ cp helm.key.pem $(helm home)/key.pem
```

Then run:

```shell
helm ls --tiller-namespace tiller --tls
```

While this works well for a single cluster, things may become a little bit more complicate if you need to manage more than a single cluster. Following is reported a workaround (original idea comes from [this interesting article](https://medium.com/nuvo-group-tech/configure-helm-tls-communication-with-multiple-kubernetes-clusters-5e58674352e2) article).

* Create this directory structure:

```shell
.helm
    |
    tls
       |
       name-of-cluster-1-as-appears-in-kubectl-config-get-contexts
                |
                ca.pem
                cert.pem
                key.pem
       name-of-cluster-2-as-appears-in-kubectl-config-get-contexts
                |
                ca.pem
                cert.pem
                key.pem
```

Then, add to your *.bash_profile* or *.bash_rc* the following aliases

```shell
function get_kubectl_context() {
  echo $(kubectl config get-contexts | grep '*' | awk '{print $3}')
}

function helmet() {
  helm "$@" $(tls)
}

alias tls='echo -n "--tiller-namespace tiller --tls --tls-cert $(helm home)/tls/$(get_kubectl_context)/cert.pem --tls-key $(helm home)/tls/$(get_kubectl_context)/key.pem --tls-ca-cert $(helm home)/tls/$(get_kubectl_context)/ca.pem"'
```

So, now accessing the clusters with the right credentials and parameters will become easy as `helmet ls`

## Deploy Azure Storage PersistentVolumeClaim (PVCs) for IO services

PVCs for IO services are defined outside the helm-charts to avoid their deletion while a chart gets removed for maintenance, or simply for human errors.
PVC definitions can be found in the *storage* folder. Each PVC is prefixed with the name of the chart that makes use of it, and should be created before installing the corresponding chart.

To create a PVC, run

```shell
kubectl apply -f storage/SERVICE_NAME.yaml
```

PVCs can also be addded all at once, running

```shell
kubectl apply -f storage
```

When no longer needed, PVCs can be either directly deleted or removed passing their yaml file. For example:

```shell
kubectl delete -f storage/SERVICE_NAME.yaml

# OR

kubectl delete pvc XXX
```

PVCs have generally been set with a retention policy, meaning the related persistent volume (PV) does not get deleted automatically upon PVC deletion. To delete unused PVs (marked in `kubectl get pv` as *Released*) you can run:

```shell
kubectl delete pv XXX
```

## Deploy generic resources and services

IO services are packaged using helm charts.
Each helm chart configures one or more of the following services:

* Deployments

* Services and load balancers

* Nginx ingress rules (if any)

* Certificate requests (if any)

>NOTE: for security reasons, charts can only be deployed either in the default or in dedicated namespaces, but not in the system namespace.

To list existing deployments, run:

```shell
helm --tls --tiller-namespace tiller ls
```

To deploy an IO service:

```shell
helm install --tls --tiller-namespace tiller [-n NAMESPACE] [-f configs/CONFIG_NAME.yaml] [-n DEPLOYMENT_NAME] {NAME_OF_YOUR_CHART}
```

Where:

* CONFIG_NAME is optional and it's one of the configurations in the configs folder. By default, the *development* environment configuration is applied by default. So, for *dev* environments no configurations should be specified.

* DEPLOYMENT_NAME is optional, but strongly suggested. It represents an arbitrary name to give to the deployment (names can then be listed with `helm ls`, and used to reference charts in other helm commands)

* NAMESPACE is the namespace where to install the chart. For example, onboarding for the io-onboarding-pa charts.

* NAME_OF_YOUR_CHART is mandatory and corresponds to one of the folder names, each one representing the chart.

For example

```shell
helm install --tls --tiller-namespace tiller -n app-backend app-backend
```

To deploy the same app-backend app, applying the production configuration

```shell
helm install --tls --tiller-namespace tiller -f configs/prod.yaml -n app-backend app-backend
```

To remove an existing IO service

```shell
helm delete --tls --tiller-namespace tiller --purge [DEPLOYMENT_NAME]
```

### Kubernetes secrets

The majority of the charts need some secrets to be populated in the Azure Keyvault, before being deployed. Some exceptions apply to charts that still do not support this kind of synchronization.
Secrets need of course to follow specific name nomenclatures that match what's defined in the charts. Refer to the chart value files and readmes to know what secrets need to be defined before installing the chart.

Secrets usually are in the format: *k8s-chart_name-secret-secret_name*.

### The special case of pagopa-proxy

*pagopa-proxy* needs to be deployed in a very specific way. For more info on its deployment, take a look at the [pagopa-proxy readme](pagopa-proxy/README.md).

## First-time setup

The paragraph reports the instructions to go through the setup of a brand new cluster, just setup on Azure. Essentially, these are system configuration that are needed by all other components (IO services) to work. The guide assumes that the cluster has just been provisioned on Azure an no other actions have been taken.

### Download the cluster admin kubernetes configuration file

Before RBAC access gets configured, a generic administrator should access the cluster using the Kubernetes admin configuration file. The file can be downloaded by anyone who has an Azure role of Kubernetes administrator (and above). To download it

```shell
az aks get-credentials -n AKS_CLUSTER_NAME -g RESOURCE_GROUP --admin
```

You should now be able to access all the cluster resources in all namespaces using kubectl. You con now proceed with the system configurations.

> **WARNING:** The following commands should generally run once, while setting up the cluster the first time. Make sure this is your case before proceeding. If you run them anyway, nothing bad should happen, since all of them should be idempotent.

All system related configurations can be found in the system folder. Files are divided in three categories (indicated by a name prefix):

* common: configurations valid for all environments

* dev: configurations valid for the dev environment

* prod: configurations valid for the prod environment

Following configurations are based on the dev environment. They can be replicated for the production environment, simply substituting the dev-prefixed files with prod-prefixed files.

### Storage and data persistence

Two *Azure disk custom storage classes* implement the features provided by the default storage classes, while also enabling dynamic storage resizes and setting the reclaim policy to *Retain*, thus preserving the Azure managed disks, even when a PVC gets deleted.

To deploy the custom storage classes, run:

```shell
kubectl apply -f system/common-azure-sc.yaml
```

To correctly use the storage classes created, both a ClusterRole and a ClusterRoleBinding need to be created:

```shell
kubectl apply -f system/common-azure-pvc-roles.yaml
```

### Install tiller: the server-side component of Helm

Tiller (the server-side component of helm) is required to install any other component.

#### Create certificates for Helm/Tiller

Activate TLS-based communication between the helm-client and Tiller. This provides mutual authentication and encryption, and prevents anyone from using helm without authenticating, even from inside the cluster (i.e. one of the cluster pods).

```shell
# Generate CA key
openssl genrsa -out ca.key.pem 4096

# Generate CA cert
# (you may have minor issues generating v3_ca
# extensions on MacOS. Google is you friend :))
openssl req -key ca.key.pem -new -x509 \
    -days 7300 -sha256 \
    -out ca.cert.pem \
    -extensions v3_ca

# Generate the key for the Tiller service account
openssl genrsa -out tiller.key.pem 4096

# Generate the csr for the Tiller service account
openssl req -new -sha256 \
    -key tiller.key.pem \
    -out tiller.csr.pem

# Generate the certificate for the Tiller service account
openssl x509 -req -days 365 \
    -CA ca.cert.pem \
    -CAkey ca.key.pem \
    -CAcreateserial \
    -in tiller.csr.pem \
    -out tiller.cert.pem

# Generate the key for the clients
openssl genrsa -out client.key.pem 4096

# Generate the csr for the clients
openssl req -new -sha256 \
    -key client.key.pem \
    -out client.csr.pem

# Generate the certificate for the clients
openssl x509 -req -days 365 \
    -CA ca.cert.pem \
    -CAkey ca.key.pem \
    -CAcreateserial \
    -in client.csr.pem \
    -out client.cert.pem
```

#### Tiller namespace, Role, ClusterRoles and RoleBindings

Install Tiller in a dedicated namespace and give its service account specific permissions to only operate in some specific namespaces (i.e. not in kube-system!). Double check in the [system/common-tiller-config.yaml file](system/common-tiller-config.yaml) file what namespaces and privileges have been granted to Tiller. Then, run:

```shell
kubectl apply -f system/common-tiller-config.yaml
```

Finally, Tiller can be installed running:

```shell
helm init \
    --tiller-tls \
    --tiller-tls-cert tiller.cert.pem \
    --tiller-tls-key tiller.key.pem \
    --tiller-tls-verify \
    --tls-ca-cert ca.cert.pem \
    --service-account tiller \
    --tiller-namespace tiller \
    --history-max 200
```

### Enable synchronization of Azure Keyvault secrets with Kubernetes secrets

It's strongly recommended to make Kubernetes retrieve secrets from the Azure Keyvault, instead of manually creating and editing secrets directly in Kubernetes. This approach is safer and allows an easier maintenance of the Kubernetes cluster.

The secrets synchronization and container injection is realized using the [Azure Kevault to Kubernetes plugin](https://github.com/SparebankenVest/azure-key-vault-to-kubernetes).

Most of the charts contain a *azure-key-vault-secrets.yaml* file that creates

* A Kubernetes empty secret

* AzureKeyVaultSecret objects that trigger the pull of the secrets from the Azure Keyvault, synchronize the value with the local Kubernetes secret, and inject them as environment variables in the chart containers as needed

* Moreover, environment variables are imported in the *deployment.yaml* files with the value format `name-of-the-variable@azurekeyvault`

To install the Azure Keyvault Secrets plugin:

```shell
# Create a dedicated namespace
kubectl create namespace azurekeyvaultsecrets

# Add the repo and update local indexes
helm repo add spv-charts http://charts.spvapi.no
helm repo update

# Fetch and untar the env-injector chart
helm fetch spv-charts/azure-key-vault-env-injector --version 0.1.4 --untar

# Render the template and install the env-injector
helm template azure-key-vault-env-injector \
    -n key-vault-env-injector \
    --namespace azurekeyvaultsecrets \
    --set installCrd=false \
    | kubectl apply -n azurekeyvaultsecrets -f -

# Fetch and untar the controller chart
helm fetch spv-charts/azure-key-vault-controller --version 0.1.22 --untar

# Render the template and install the env-controller
helm template azure-key-vault-controller \
    -n key-vault-controller \
    --namespace azurekeyvaultsecrets \
    | kubectl apply -n azurekeyvaultsecrets -f -
```

#### Enable automatic environment variables injection

Enable the automatic env variables injection for all containers in the default namespace:

```shell
kubectl apply -f system/common-azure-key-vault.yaml
```

### Deploy the cert-manager

The cert-manager is a Kubernetes component that takes care of adding and renewing TLS certificates for any virtual host specified in the ingress, through the integration with some providers (i.e. letsencrypt) .

> **Warning:** If the first command generates a validation error, you should update the *kubectl* client.

To deploy the cert-manager, run:

```shell
kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.11.0/cert-manager.yaml

kubectl label namespace cert-manager cert-manager.io/disable-validation=true
```

>More info can be found on the [official cert-manager website](https://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html#steps).

#### Apply cert-manager issuers

To integrate the cert-manager with the *letsencrypt certificate issuer*, run:

```shell
kubectl apply -f system/common-cert-manager-issuers.yaml
```

### Deploy Application Gateway Ingress Controller (AGIC)

IO ingress functionalities are realized through the integration with the Azure Application Gateway with a component called [Application Gateway Ingress Controller (AGIC)](https://azure.github.io/application-gateway-kubernetes-ingress/). Integrating with the Application Gateway allows a better security, for example against volumetric attacks.

The following steps allow to configure the AGIC component on a brand new Kubernetes cluster and assume that a compliant Application Gateway has been already provisioned with [Terraform](https://github.com/teamdigitale/io-infrastructure-live).

>NOTE: substitute any reference of dev with prod as needed (if you're configuring a production environment)

```shell
# Create a dedicated namespace
kubectl create namespace ingress-azure

# Add the AGIC helm repository and update the dependencies
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

# Fetch the AGIC chart locally
helm fetch application-gateway-kubernetes-ingress/ingress-azure --version 1.0.0 --untar

# Create a Service Principal and locally save its authentication info
secretJson=$(az ad sp create-for-rbac --subscription ec285037-c673-4f58-b594-d7c480da4e8b --name io-dev-sp-k8s-01-agw --sdk-auth | base64 -b 0)

# Locally save the Kubernetes cluster API server address
apiServerAddress=$(az aks show -n io-dev-aks-k8s-01 -g io-dev-rg --query fqdn | sed 's/"//g')

# Install the Application Gateway Ingress Controller
helm template ingress-azure \
  --name ingress-azure \
  --namespace ingress-azure \
  --set appgw.name=io-dev-ag-to-k8s-01 \
  --set appgw.resourceGroup=io-dev-rg \
  --set appgw.subscriptionId=ec285037-c673-4f58-b594-d7c480da4e8b \
  --set appgw.shared=false \
  --set appgw.usePrivateIP=false \
  --set armAuth.type=servicePrincipal \
  --set armAuth.secretJSON=$secretJson \
  --set rbac.enabled=true \
  --set verbosityLevel=3 \
  --set aksClusterConfiguration.apiServerAddress=$apiServerAddress | kubectl apply -n ingress-azure -f -
```

### Create Kubernetes roles and map Azure groups

One or more Active Directory groups should have already been created through [Terraform](https://github.com/teamdigitale/io-infrastructure-live). It's time to create some Kubernetes roles and map them to the groups created.

* Open the *dev-azure-aad-cluster-roles.yaml* file and make sure the group names are up to date. Groups names (IDs) can be found in the Azure GUI under Azure Active Directory -> Groups -> Name of the group -> Overview

* Apply the roles and role bindings

```shell
kubectl apply -f system/dev-azure-aad-cluster-roles.yaml
```

## How to contribute

Contributions are welcome. Feel free to open issues and submit [pull requests](./pulls) at any time, but please read [our handbook](https://github.com/teamdigitale/io-handbook) first.

## License

Copyright (c) 2019 Presidenza del Consiglio dei Ministri

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program.  If not, see <https://www.gnu.org/licenses/>.
ot, see <https://www.gnu.org/licenses/>.
