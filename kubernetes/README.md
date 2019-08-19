# IO (Digital Citizenship) Kubernetes confiuration files

This directory contains the configuration for deploying the backend components
of the IO project in the Kubernetes (K8S) cluster, previously provisioned by Terraform.

## What is IO?

More informations about the IO can be found on the [Digital Transformation Team website](https://teamdigitale.governo.it/en/projects/digital-citizenship.htm)

## Tools references

The tools used in this repository are

* [Kubernetes](https://kubernetes.io)

* [Helm](https://helm.sh/)

## Repository structure

All *yaml* files in the root folder are related to application deployments (pods). They can be deployed in any order.

The *system* directory contains a set of *yaml* files that are needed to configure the basic system components, such as the ingress controller or the certificate manager. More info can be found in the README.md file in the system folder.

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

- To see your contexts: `kubectl config get-contexts`
- To use your context: `kubectl config use-context CONTEXT_NAME`

More info [here](https://kubernetes-v1-4.github.io/docs/user-guide/kubectl/kubectl_config_use-context/)

8. At this point you should be able to see the available PODs on the cluster, if any: `kubectl get pods`, and the helm deployments, if any and if helm is installed (`helm ls`). See further instructions below if it's not.
>NOTE: Your helm client may not be in sync with the Tiller version installed on the server. In these case you can run *helm init --upgrade* to synchronize the two versions.

9. **IMPORTANT:** Before proceeding, make sure you've installed the system components. Otherwise, likely the installation of the applications will fail.

10. Most of the applications below will make use of some secrets, stored manually in Kubernetes. Make sure all secrets are present, and in case copy them from previous deployments.

## Files and folder structure

The `kubernetes` folder contains different files and folders, each one generally representing a service of IO.

Applications are usually distributed as *helm charts*. Just few system configurations are still applied using single *yaml* files.

Some of the folders under the root kubernetes directory realize more specific functions:

* **system** - contains scripts to apply the basic Kubernetes system configurations (follow the readme.md inside the system folder for more info)

* **configs** - helm configuration value files that can be optionally used to extend the basic helm charts default values. Each file generally represents a deployment environment (i.e. dev, prod, ...)

## Deploy generic resources and services using kubectl

To deploy a service using kubectl:

```shell
kubectl apply -f NAME_OF_THE_FILE.yaml
```

For example

```shell
kubectl apply -f cert-manager-issuers.yaml
```

## Deploy generic resources and services using helm

IO services are packaged using helm charts.

Helm charts are represented as collections of files, contained in a folder named as the service that implements.

The main advantage of using helm charts is that they are designed as templates that expose variables that can be easily extended.

Each helm chart configures one or more of the following services:

* Deployment

* Services and load balancers

* Nginx ingress rules (if any)

* Certificates (if any)

To list existing deployments

```shell
helm ls
```

To deploy a service

```shell
helm install [-f configs/CONFIG_NAME.yaml] [-n DEPLOYMENT_NAME] {NAME_OF_YOUR_CHART}
```

Where:

* CONFIG_NAME is optional and it's one of the configurations in the configs folder

* DEPLOYMENT_NAME is optional. It represents an arbitrary name to give to the deployment (names can then be listed with `helm ls`, and used to reference charts in other helm commands)

* NAME_OF_YOUR_CHART is mandatory and corresponds to one of the folders (each one is a different chart) in the kubernetes directory, besides the special folders reported in the folder structure paragraph, above

For example

```shell
helm install -f configs/dev.yaml -n io-onboarding-pa io-onboarding-pa
```

To remove an existing PDND service

```shell
helm delete --purge [DEPLOYMENT_NAME]
```
