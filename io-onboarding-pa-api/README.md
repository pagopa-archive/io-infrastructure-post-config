# IO Onboarding PA backend (API)

This is the chart to install the backend services of the IO PA onboarding portal.

## Installation

Some secrets need to be installed before being able to proceed with the chart installation. Postgres will be installed using its official helm-chart as a dependency of the main chart.

### Create the postgres secret

* Edit and apply the *postgres-secret.yaml* file in this directory to create a local kubernetes secret for postgres.

```shell
kubectl apply -f io-onboarding-pa-api/postgres-secret.yaml
```

>NOTE: the postgres official helm-chart still does not support the AzureKeyvaultSecrets plugin.

### Import SPID certificates

* Import SPID TLS certificates in PEM format into the Azure Keyvault, using the Azure GUI. The certificate and the key must be places one after the other, in PEM format in the same file. The name of the secret should be *k8s-io-onboarding-pa-api-secrets-spid-certs*.

### Install the chart and its dependencies

```shell
cd io-onboarding-api
helm dep update
cd ..
helm install -n io-onboarding-pa-api io-onboarding-api
```
