# PagoPA proxy

The [IO PagoPA Proxy](https://github.com/teamdigitale/io-pagopa-proxy) allows the IO applications to communicate with PagoPA, essentially providing two functionalities:

* Expose a REST API interface to the IO backend. The API calls are converted to SOAP calls to PagoPA (and viceversa)

* Provide TLS 1.2 authentication and encryption services for the communications with PagoPA

## Kubernetes package composition

The PagoPA proxy application is distributed as a helm-chart, which installs a Kubernetes service to get calls from the other IO services, an ingress to expose its SOAP interface to PagoPA, and Kubernetes POD made of two containers:

* The *pagopa-proxy* container, running the application that performs the REST-SOAP conversions. The source code of the application and more info about it are available on [GitHub](https://github.com/teamdigitale/io-pagopa-proxy)

* The *pagopa-proxy-nginx-tls* container: a sidecar container running NGINX, proxying the requests from the PagoPA application and transparently (for the pagopa-proxy application) adding the keys and certificates needed for IO to authenticate and encrypt traffic, while talking to PagoPA

The container also authenticates incoming requests from PagoPA using the ingress gateway functionalities exposed by the NGINX ingress container already installed in the system (see more under the folder *system* and look at the *ingress.yaml* file in this helm-chart).

## Communication Flow

An egress request going from an IO application to PagoPA

```
                               _________________pod pagopa-proxy___
           ____________       | ______________       _____________ |
REST      |            |      ||              |     | pagopa-proxy||   PagoPA
from ->:80|pagopa-proxy|->:8080| pagopa-proxy |->:80| -nginx-tls  |-->:443
 IO       |   service  |      ||   container  |     |  container  ||   SOAP
          |____________|      ||______________|     |_____________||   call
                              |____________________________________|
```

* An IO component sends a request to the pagopa-proxy service, on port 80

* The pagopa-proxy container forwards the request to the pagopa-proxy-nginx-tls container in the same POD, port 80

* The pagopa-proxy-nginx-tls container authenticates with PagoPA, encrypts the traffic and forwards it to PagoPA, port 443

## How the TLS authentication and encryption with PagoPA works

Before communicating, IO and PagoPA perform a mutual TLS (certificate-based) authentication. Then, the overall session gets encrypted, always using TLS.

Depending on the primitives called, there are two major, distinct communication phases:

* IO acts as the client and PagoPA as the server

* PagoPA acts as the client and IO as the server

When one of the two parties acts as the server, it requires the other to present itself with a key and a certificate, in order to authenticate it and being able to communicate.

The server always presents itself with a public server certificate, to make the client validate its identity and avoid man-in-the-middle attacks.

Servers should always verify clients authenticity using a corresponding CA chain certificate and they should also authorize specific clients to access, explicitly trusting their certificates (or at least checking the certificate CN). Certificates are previously provided by the peering partner (IO if PagoPA is the server, PagoPA if IO acts as the server).

As such, when a client wants to initiate a connection to the server, it needs to provide 1) a valid public certificate (that needs to match the one previously shared with the partner) 2) a private key matching the certificate, that won't be of course exchanged with the server, but used to encrypt the traffic.

It's a common practice for connections with PagoPA to use the same key and certificate, both while acting as the server, and while acting as the client.

## PagoPA static DNS entry

For security reasons, the PagoPA hostnames used in this chart (i.e. *gad.test.pagopa.gov.it*) are not publicly resolved. As such, the IP endpoints need to be previously requested to PagoPA and static DNS entries need to be manually populated in the CoreDNS configuration (see how in the installation and configuration paragraph, below).

# How to install and configure PagoPA proxy

To establish a successful communication with PagoPA the following actions need to be performed:

* **Communicate your public IP to PagoPA:** PagoPA filters ingress communications using IP filters (and so should do IO). The first load balancer external, public IP configured in the cluster -presumably the one associated with the NGINX ingress- is also set by default as the cluster egress IP. Make sure to communicate the IP to PagoPA, so it will be added to their whitelist.

* **Get the PagoPA public IPs and populate CoreDNS with static entries** creating a file locally on your machine, like the one below.

```yaml
apiVersion: v1
data:
  custom_dns_entries.override: |
    hosts {
      X.Y.W.Z gad.test.pagopa.gov.it
      fallthrough
    }
kind: ConfigMap
metadata:
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
    k8s-app: kube-dns
    kubernetes.io/cluster-service: "true"
  name: coredns-custom
  namespace: kube-system
```

The following example sets a custom DNS entry that binds *gad.test.pagopa.gov.it* to the IP *X.Y.W.Z*. You should change it and add as many IP/DNS entries as needed (one per line).

Then, apply the file running `kubectl apply -f dns-custom.yaml`

>**WARNING**: Do not publicly commit the PagoPA IP addresses to do not compromise the security policies of PagoPA.

* **Generate test certificates (optional):** while PagoPA will always use official CA released certificates, during the initial test phase it may be beneficial for the counterpart to generate temporary, self-signed certificates. This can be easily achieved using *openssl*:

```shell
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=pagopa.dev.io.italia.it/O=pagopa.dev.io.italia.it"
```

The example creates a public certificate called *tls.crt* and a private key named *tls.key*. *CN* and *O* values should be adjusted to the specific hostname in use.

* **Load the IO (client/server) certificates as Kubernetes secrets:** the private key *tls.key* and the public certificate *tls.crt* need to be loaded in Kubernetes as secrets.

```shell
kubectl create secret tls pagopa-proxy-io-test-certs --key tls.key --cert tls.crt
```

The command loads *tls.key* and *tls.crt* in a Kubernetes secret called *pagopa-io-test-certs*. Adjust values as needed.

* **Create the full-chain CA certificate**

To create a full-chain CA certificate, used to validate PagoPA certificates:

  * Create an empty file called *ca-chain-cert.pem*

  * Copy to the *ca-chain-cert.pem* file just created the *DigiCert High Assurance EV Root CA* certificate from [this page](https://www.sslsupportdesk.com/digicert-root-cas/)

  * Copy to the *ca-chain-cert.pem*, below the root certificate just copied, the content of the *DigiCert SHA2 Extended Validation Server CA* certificate from [this page](https://www.sslsupportdesk.com/digicert-intermediate-cas/)

>**NOTE**: These steps assume that the certificates have been signed by DigiCert CA. If the ca-chain-cert.pem file loaded is not able to validate the PagoPA certificate make sure the certificate has been released by Digicert. Apply otherwise the similar procedure to other CAs.

* **Load the PagoPA full-chain CA certificate in Kubernetes:** after obtaining the full-chain certificate, create an ad-hoc secret in Kubernetes:

```shell
kubectl create secret generic pagopa-proxy-pagopa-ca-test-certs --from-file=ca.crt=ca-chain-cert.pem
```

Adjust the name of the secret and the name of the file as needed.

* **Create all other secrets, needed by the helm-chart**: the helm-chart requires additional secrets to be set. To load the secrets in Kubernetes, create a yaml file as below and apply it with `kubectl apply -f my_secrets_file.yaml`

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: pagopa-proxy
type: Opaque
stringData:
  id_canale: "XXX"
  id_canale_pagamento: "XXX"
  id_intermediario_psp: "XXX"
  id_psp: "XXX"
  pagopa_password: "XXX"
  redis_password: "XXX"
```

The file above contains a list of exemplar variables and values placeholders. Please, check the values.yaml of this chart for the updated list of secrets and adjust the values as needed.

* **Deploy the pagopa-proxy helm-chart**

```shell
helm install -n pagopa-proxy pagopa-proxy
```