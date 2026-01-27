# OpenShift CI/CD Test

This repo contains an example of how to configure application builds and deployments against an OpenShift cluster.
The example is intended to be run locally using OpenShift Local.

GitHub Actions is the primary CI/CD tool in use, but parallels will be drawn with GitLab Pipelines.

## Configuring the Cluster

The following subsections explain...

1. How to generate a simple self-signed certificate authority (CA)
2. How to configure the default ingress CA in OpenShift
3. How to configure TLS on Ingress resources
4. How to configure TLS on HttpRoute resources
5. How to create and sign certificate requests with Cert Manager

### Prerequisites

It's recommended to start with a freshly-installed OpenShift Local cluster.

If you already have an OpenShift Local cluster running, you can delete the existing cluster and create a new one with the following commands.

```shell
crc delete
crc start
```

Also, make sure you're currently logged in with the `kubeadmin` account.

```shell
oc login -u kubeadmin https://api.ctc.testing:6443
```

## Create an external certificate Authority

In practice the CA will come from some external source, such as a verified .
For this tutorial, we'll create a local self-signed CA to test with.

First, lets generate the root CA private key.

```shell
openssl genrsa -out ./ca/certs/ca.key 2048
```

```shell
$ openssl req -new -x509 -key ./ca/certs/ca.key -out ./ca/certs/ca.crt
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:US
State or Province Name (full name) [Some-State]:Iowa
Locality Name (eg, city) []:Des Moines
Organization Name (eg, company) [Internet Widgits Pty Ltd]:Example Org
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:
Email Address []:
```

## Generate a certificate for the ingress controller

Generate a private key for the cert.

```shell
openssl genrsa -out ./ca/certs/ingress.key 2048
```

Create the certificate signing request (CSR).
`openssl` will prompt for input, example values are provided in the output below.

```shell
$ openssl req -new -key ./ca/certs/ingress.key -out ./ca/certs/ingress.csr
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:US
State or Province Name (full name) [Some-State]:Iowa
Locality Name (eg, city) []:Des Moines
Organization Name (eg, company) [Internet Widgits Pty Ltd]:Example Org
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:*.apps.crc.testing
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

Sign the certificate with our CA.

```shell
$ openssl x509 -req -in ./ca/certs/ingress.csr -CA ./ca/certs/ca.crt -CAkey ./ca/certs/ca.key -CAcreateserial -out ./ca/certs/ingress.crt
Certificate request self-signature ok
subject=C=US, ST=Iowa, L=Des Moines, O=Example Org, CN=*.apps.crc.testing
```

Verify everything has been created properly up to this point.

```shell
$ openssl verify -CAfile ./ca/certs/ca.crt ./ca/certs/ingress.crt
./ca/certs/ingress.crt: OK
```
