# PagoPA proxy

[IO PagoPA Proxy](https://github.com/teamdigitale/io-pagopa-proxy) allows the IO mobile application backend to communicate with PagoPA, essentially providing two functionalities:

* Expose a REST API interface to the IO backend: the API calls are converted to SOAP calls to PagoPA and viceversa

* Provide TLS 1.2 authentication and encryption services between IO and PagoPA

*pagopa-proxy* is a quite articulated piece of software, which deserves a dedicated readme and needs to be deployed in a very specific way. Please read carefully this document before proceeding any further with the deployment.

## Code documentation

This readme explains what's the architecture of the pagopa-proxy helm-package, and how to deploy it and maintain it. If you're looking for code-specific docs, you can have a look in the [pagopa-proxy dedicated repository](https://github.com/teamdigitale/io-pagopa-proxy).

## Kubernetes package composition

Pagopa-proxy is distributed as a helm-chart, deploying two containers:

* The *pagopa-proxy* container, running the application that performs the REST-SOAP conversions. Again, the source code of the application and more info about it are available on [GitHub](https://github.com/teamdigitale/io-pagopa-proxy)

* The *pagopa-proxy-nginx-tls* container: a sidecar container running NGINX, that proxies requests from the pagopa-proxy container to PagoPA and viceversa, providing authentication and encryption.

## PagoPA environments and their relation with IO

PagoPA delivers its payment functionalities through some *payment nodes*, which are divided in *test payment nodes* and *production payment nodes*. As opposed to production nodes, test payment nodes can't be used for real payments. At the current time, payment nodes only support a single peer (for example, one connection with pagopa-proxy).

While the IO *dev* environment should only interact with a *test development node*, the *prod* environment should interact with both a *test* and a *development* node. Test nodes in the context of the IO prod environment generally allow end Public Administration users to test the payment process before sending a real message to citizens.

### Hostnames and certificates

Each pagopa-proxy instance connecting to PagoPA should listen for connections, and connect to PagoPA using a specific hostnames and specific certificates. At the same time, each PagoPA node type (test or prod) should be exposing specific hostnames, and consequentially expose dedicated certificates. More examples are reported below.

### Helm-chart configuration extensions

While the *pagopa-proxy* helm-chart remains one, different configuration files in the [configs folder](configs) can extend it. The default configuration deploys *pagopa-proxy* in the *dev* environment, allowing connections to the *PagoPA test payment node*.

Here are the extra configurations available:

* [prod.yaml](configs/prod.yaml): extends the basic helm-chart configuration to deploy *pagopa-proxy* connecting to the *PagoPA test payment node* in the production environment

* [pagopa-proxy-prod.yaml](configs/pagopa-proxy-prod.yaml): extends the basic helm-chart configuration and it's used together with the [prod.yaml configuration](configs/prod.yaml) to deploy a *pagopa-proxy* in the IO production environment, which connects to a *production payment node*

## Deployment process

Follow these steps to deploy *pagopa-proxy*:

* **Communicate your public IP to PagoPA**: PagoPA filters ingress communications using IP filters (and so IO should do). This is usually the public IP of the application gateway associated with the Kubernetes cluster. Make sure to communicate the IP to PagoPA, so it will be added to their whitelist.

* For security reasons, the PagoPA hostnames used in this chart (i.e. *gad.test.pagopa.gov.it*) are not publicly resolved. As such, the IP endpoints need to be previously requested to PagoPA (i.e. email) and static DNS entries should to be manually populated in the CoreDNS Kubernetes configuration (see how in the installation and configuration paragraph, below). Start creating the following yaml file:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
data:
  custom_dns_entries.override: |
    hosts {
      X.Y.W.Z gad.test.pagopa.gov.it
      fallthrough
    }
```

The following example sets a custom DNS entry that binds *gad.test.pagopa.gov.it* to the IP *X.Y.W.Z*. You should change it and add as many IP/DNS entries as needed (one per line, before *fallthrough*).

Name the file -for example- *dns-custom.yaml*. Then, apply the Kubernetes configuration running `kubectl apply -f dns-custom.yaml`

>**WARNING**: Do not commit the PagoPA IP addresses. It would compromise the security policies of PagoPA.

Now, force CoreDNS to reload its ConfigMaps. The `kubectl delete pod` command isn't destructive and doesn't cause any down time. The kube-dns pods will get deleted, and the Kubernetes scheduler will recreate them.

```shell
kubectl delete pod --namespace kube-system -l k8s-app=kube-dns
```

* **Import IO TLS certificates (public + intermediate certificate and private keys) in PFX format into the Azure Keyvault** using the Azure GUI (Azure keyvault -> select your keyvault -> certificates -> upload/import). Call the certificate *k8s-pagopa-proxy-NODE-TYPE-secrets-io-certs*, where *NODE-TYPE* can be either *test* or *prod*, depending on PagoPA node type you're connecting to (i.e. test or prod).

* **Import the PagoPA CA chain certificate into the Azure Keyvault** as a unique Keyvault *secret* (not as a certificate!). The secret consists of a multi-line text, but it's saved in the Keyvault as a one-line string. For this reason, it can be either:
  
  * input directly from the GUI, if correctly placed before in a text editor on a single line, and adding `\n` at the end of each line

  * input directly from the GUI in PFX format

  * Imported using the *az CLI tool* with the following command:
    ```shell
    az keyvault secret set --vault-name YOUR_KEYVAULT_NAME --name AZURE_SECRET_NAME --file CA_CHAIN_FILE_NAME
    ```
    The command automatically formats the file and stores it in the Azure Keyvault.

The PagoPA CA chain certificate secret name should be: *k8s-pagopa-proxy-NODE-TYPE-secrets-pagopa-ca-chain-certs*, where *NODE-TYPE* can be either *test* or *prod*, depending on PagoPA node type you're connecting to (i.e. test or prod).

* **Create all other secrets**: create an Azure Keyvault secret in Json format through the Azure portal GUI. The name of the secret should be *k8s-pagopa-proxy-NODE-TYPE-secrets*, where *NODE-TYPE* can be either *test* or *prod*, depending on PagoPA node type you're connecting to (i.e. test or prod). The secret should have the following content `{"pagopa-password": "XXX", "pagopa-id-psp": "XXX", "pagopa-id-int-psp": "XXX", "pagopa-id-canale": "XXX", "pagopa-id-canale-pagamento": "XXX", "redis-db-password": "XXX"}`. Substitute *XXX* as appropriate.

* **Install the chart**

The chart needs a specific name, depending on its function:

* to reach PagoPA test environments: *pagopa-proxy-test*

* to reach PagoPA production environments: *pagopa-proxy*

These are the procedures to install the chart, depending by the IO environment you're deploying the chart into and by the function of the PagoPA node you're connecting to:

| IO env | PagoPA node function | Command | 
| ------ | -------------------- | ------------------------------------------- |
| dev | pagopa-test | `helm install -n pagopa-proxy-test pagopa-proxy` |
| prod | pagopa-test | `helm install -f configs/prod.yaml -n pagopa-proxy-test pagopa-proxy`|
| prod | pagopa-prod | `helm install -f configs/pagopa-proxy-prod.yaml -f configs/prod.yaml -n pagopa-proxy pagopa-proxy`|

* **Modify Azure Application Gateway health probe**: the pagopa-proxy is deployed behind an [Application Gateway](https://azure.github.io/application-gateway-kubernetes-ingress/), which sits in front of the Kubernetes cluster for security reasons. The type of probe used by pagopa-proxy is still not fully compatible with the Application Gateway probes. For this reason the probe created needs to be modified manually, so the application gateway probe won't fail and the endpoint will be reachable. To do so, reach the application gateway through the Azure portal. Go to *Health Probes*. Find the health probe reaching pagopa-proxy and select it. Change the path to */healthz*. Test and save.

## Example of an egress flow from IO to PagoPA

The following diagram shows an egress request going from the IO mobile application backend to PagoPA

```
                               _________________pod pagopa-proxy___
           ____________       | ______________       _____________ |
REST      |            |      ||              |     | pagopa-proxy||   PagoPA
from ->:80|pagopa-proxy|->:8080| pagopa-proxy |->:80| -nginx-tls  |<-->:443
 IO       |   service  |      ||   container  |     |  container  ||   SOAP
          |____________|      ||______________|     |_____________||   call
                              |____________________________________|
```

* The app backend sends a request to the pagopa-proxy service, on port 80

* The pagopa-proxy service forwards to the pagopa-proxy container, port 8080

* The pagopa-proxy container forwards to the pagopa-proxy-nginx-tls container in the same pod (localhost), port 80. A virtualhost called *pagopa* has been configured in the *pagopa-proxy-nginx-tls* container to match the request

* The pagopa-proxy-nginx-tls container authenticates with PagoPA, encrypts the traffic and forwards it to PagoPA, towards port 443

## How the TLS authentication and encryption with PagoPA works

Before communicating, IO and PagoPA perform a mutual TLS (certificate-based) authentication. Then, a session is formed and gets encrypted, always using TLS.

Depending on the primitives called, there are two major, distinct communication phases:

* IO acts as the client and PagoPA as the server

* PagoPA acts as the client and IO as the server

When one of the two parties acts as the server, it requires the other to present itself with a valid key and certificate, in order to authenticate and being able to communicate.

The server always presents itself with a public server certificate, to make the client validate its identity and avoid man-in-the-middle attacks.

Servers should always verify clients authenticity using a corresponding CA chain certificate and they should also authorize specific clients to access, explicitly trusting their certificates (or at least checking the certificate CN). Certificates are previously provided by the peering partner (IO if PagoPA is the server, PagoPA if IO acts as the server).

As such, when a client wants to initiate a connection to the server, it needs to provide 1) a valid public certificate (that needs to match the one previously shared with the partner) 2) a private key matching the certificate, that won't be of course exchanged with the server, but used to encrypt the traffic.

It's a common practice for connections with PagoPA to use the same key and certificate, both while acting as the server, and while acting as the client.

## Build test SSL Certificates

While PagoPA will always use official CA released certificates, during the initial test phase it may be beneficial for the counterpart to generate temporary, self-signed certificates for test purposes. This can be easily achieved using *openssl*:

```shell
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=pagopa-test.dev.io.italia.it/O=IO"
```

The example creates a public certificate called *tls.crt* and a private key named *tls.key*. *CN* and *O* values should be adjusted to the specific hostname in use for the demo (can be changed in [values.yaml](values.yaml)).

* **Create the full-chain CA certificate**

To create a full-chain CA certificate, used to validate PagoPA certificates:

  * Create an empty file called *ca-chain-cert.pem*

  * Copy to the *ca-chain-cert.pem* file just created the *DigiCert High Assurance EV Root CA* certificate from [this page](https://www.sslsupportdesk.com/digicert-root-cas/)

  * Copy to the *ca-chain-cert.pem*, below the root certificate just copied, the content of the *DigiCert SHA2 Extended Validation Server CA* certificate from [this page](https://www.sslsupportdesk.com/digicert-intermediate-cas/)

>**NOTE**: These steps assume that the certificates have been signed by DigiCert CA. If the ca-chain-cert.pem file loaded is not able to validate the PagoPA certificate make sure the certificate has been released by Digicert. Apply otherwise the similar procedure to other CAs.

## Test the egress connection to PagoPA

To test the egress connection to PagoPA (thus verifying to be able to authenticate), the quickest thing to do is to manually enter in the pagopa-proxy container and curl PagoPA.
For this specific exercise, it doesn't matter what SOAP message is sent to PagoPA. What we want to test is the authentication process.
If the authentication is *successful* PagoPA will return an application error (since we're sending a random message). Otherwise, the authentication will fail and a 403 will be returned instead.

Following is a test example:

```
$ kubectl get pods
NAME                                   READY   STATUS    RESTARTS   AGE
app-backend-848f4f4b8c-27vlr           1/1     Running   0          5h41m
app-backend-848f4f4b8c-2gbfg           1/1     Running   0          5h41m
app-backend-848f4f4b8c-7m7ts           1/1     Running   0          5h41m
app-backend-848f4f4b8c-gbzp9           1/1     Running   0          5h41m
app-backend-848f4f4b8c-v2zlj           1/1     Running   0          5h41m
app-backend-848f4f4b8c-wx4c2           1/1     Running   0          5h41m
app-backend-848f4f4b8c-x2xkz           1/1     Running   0          5h41m
app-backend-848f4f4b8c-zmblh           1/1     Running   0          5h41m
io-onboarding-pa-api-7d65ffc6c-xlp2j   2/2     Running   1          28m
pagopa-proxy-85cc4ddfc6-bdtgb          2/2     Running   0          17m
spid-testenv-bcc9b4fd5-2gtfb           1/1     Running   0          5h40m

$ kubectl exec -it pagopa-proxy-85cc4ddfc6-bdtgb -c pagopa-proxy /bin/sh
/usr/src/app #

/usr/src/app # apk update && apk add curl

# Following command will either return an application error (SUCCESS!) or an authentication error (FAILURE :()
/usr/src/app # curl -d '<run>...</run>' http://test.pagopa/openspcoop2/proxy/PA/
```
