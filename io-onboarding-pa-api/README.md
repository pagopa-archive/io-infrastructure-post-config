# IO Onboarding PA backend (API)

This is the chart to install the backend services of the IO PA onboarding portal.

## Installation

* Create the secret *k8s-io-onboarding-pa-api-secrets-postgres-password* in your Azure Keyvault

* Import SPID TLS certificates in PEM format into the Azure Keyvault, using the Azure GUI. The certificate and the key must be places one after the other, in PEM format in the same file. The name of the secret should be *k8s-io-onboarding-pa-api-secrets-spid-certs*.

* Install the chart using the name *io-onboarding-pa-api*

```shell
helm install -n io-onboarding-pa-api io-onboarding-pa-api
```

