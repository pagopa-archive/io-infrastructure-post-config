# IO Onboarding PA backend (API)

This chart installs the backend services of the IO PA onboarding portal.

## Installation

Some secrets need to be installed before being able to proceed with the chart installation. Postgres will be installed using its official helm-chart as a dependency of the main chart.

### Create the IO onboarding PA API secrets

Some secrets need to be manually created in the Azure Keyvault before being able to install the chart. Once the chart is installed, an Azure Keyvault synchronizer will constantly keep the vault secrets monitored and it will make sure that the Kubernetes secrets remain in sync with the remote ones.

#### SPID certificates

Import the SPID certificates (in PFX format) into the Azure Keyvault, using the Azure GUI. Name the secret *k8s-io-onboarding-pa-api-secrets-spid-certs*.
 
### All other secrets

Create a secret in the Azure Keyvault named *k8s-io-onboarding-pa-api-secrets* with the following structure: `{"email-password": "YOUR_EMAIL_PASSWORD", "postgresql-password": "YOUR_POSTGRESQL_PASSWORD_HERE", "postgresql-replication-password": "YOUR_POSTGRESQL_REPLICATION_PASSWORD_HERE", "arss-identity-otp-pwd": "YOUR_ARUBA_IDENTITY_OTP_PWD", "arss-identity-user-pwd": "YOUR_ARUBA_IENTITY_USER_PWD"}`

### Install the chart and its dependencies

```shell
cd io-onboarding-api
helm dep update
cd ..
helm install --namespace onboarding -n io-onboarding-pa-api io-onboarding-api
```
