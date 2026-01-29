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

## Prepare the CA and Ingress certificates

In practice the CA will come from some external source, such as a verified CA issuer or an existing PKI.
For this tutorial, we'll create a local self-signed CA to test with.

```shell
$ openssl req -x509 -new -newkey rsa:2048 -keyout ./certs/ca.key -out ./certs/ca.crt -subj '/CN=OpenShift Lab CA' -nodes
...++++++++++++++++++++++++++++++++...
...........+.+.....+....+++++++++++...
-----
```

OpenShift requires that the certificate includes the `subjectAltName` (SAN) extension showing `*.apps.<clustername>.<domain>`.
We'll create an openssl configuration file to facilitate setting this extension when creating our CSR.
For OpenShift Local, we'll use `*.apps-crc.testing` for the SAN.

```shell
$ openssl req -new -newkey rsa:2048 -keyout ./certs/ingress.key -out ./certs/ingress.crt -CA ./certs/ca.crt -CAkey ./certs/ca.key -subj '/CN=*.apps-crc.testing' -addext 'subjectAltName = DNS:*.apps-crc.testing' -addext 'basicConstraints = critical,CA:FALSE' -nodes
...+.........+......+.....+...
.+..........+++++++++++++++...
-----
```

Verify everything has been created properly up to this point.

```shell
$ openssl verify -CAfile ./certs/ca.crt ./certs/ingress.crt
./certs/ingress.crt: OK
```

```shell
$ openssl x509 -in ./certs/ingress.crt -noout -text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number:
            10:82:28:19:04:c7:7d:5b:2c:9d:2a:7a:eb:86:89:b4:96:d8:86:47
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=*.apps.crc.testing
        Validity
            Not Before: Jan 27 21:25:28 2026 GMT
            Not After : Feb 26 21:25:28 2026 GMT
        Subject: CN=*.apps.crc.testing
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (2048 bit)
                Modulus:
                    00:dd:31:ac:0a:7d:1f:65:18:a2:5b:d2:4b:8b:df:
                    ...
                Exponent: 65537 (0x10001)
        X509v3 extensions:
            X509v3 Subject Key Identifier: 
                5A:E1:48:85:F6:74:1B:3D:EE:8B:D5:F7:71:E9:BD:12:AD:06:17:80
            X509v3 Authority Key Identifier: 
                8C:4E:D9:28:02:A4:9E:6B:61:3D:2A:1F:95:B7:39:EA:BA:A4:F6:57
            X509v3 Basic Constraints: critical
                CA:TRUE
            X509v3 Subject Alternative Name: 
                DNS:*.apps-crc.testing
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value:
        69:58:eb:5f:d5:4f:45:5b:bb:e9:c9:57:d0:e2:d8:a6:28:d4:
        ...
```

Ensure your cert contains the SAN extension.
In the above cert, this is the part that looks like:

```text
            X509v3 Subject Alternative Name: 
                DNS:*.apps-crc.testing
```

## Override the default OpenShift ingress certificate

First we need to add our CA to the cluster.
Run the following command to create a new `ConfigMap` with our CA:

```shell
$ oc create configmap custom-ca --from-file=ca-bundle.crt=./certs/ca.crt -n openshift-config
configmap/custom-ca created
```

Next we'll tell the OpenShift proxy to use the CA we just added.

```shell
$ oc patch proxy/cluster --type=merge --patch='{"spec":{"trustedCA":{"name":"custom-ca"}}}'
proxy.config.openshift.io/cluster patched
```

Then add the ingress cert and key to a `Secret`.

```shell
$ oc create secret tls ingress-tls --cert=./certs/ingress.crt --key=./certs/ingress.key -n openshift-ingress
secret/ingress-tls created
```

Finally, we'll update the ingress controller configuration to use our cert and key.

```shell
$ oc patch ingresscontroller.operator default --type=merge --patch='{"spec":{"defaultCertificate":{"name":"ingress-tls"}}}' -n openshift-ingress-operator
ingresscontroller.operator.openshift.io/default patched
```

This final command will trigger OpenShift to restart the ingress controller and a few other dependencies.
This may take some time to complete, and the console will be temporarily unavailable.

When you set up OpenShift local and used the console for the first time, your browser likely warned about an untrusted certificate.
The OpenShift console uses the same certificate for ingress, so you should see a similar warning with our new cert.

Navigate to the console when it returns, and inspect the certificate using your browser's tooling.
Your browser should report the same information about the certificate that the `openssl x509 -in ./certs/ingress.crt -noout -text` command output.

## Configure TLS on an Ingress

TODO

## Configure TLS on an HTTPRoute

TODO

## Let cert-manager control the PKI

TODO

## Troubleshooting

Verify no custom cert exists.

```shell
oc get ingresscontroller.operator default -n openshift-ingress-operator -o yaml | grep defaultCertificate
```

Expected: No output

Validate ingress certificate.

```shell
oc project openshift-ingress
oc get secret router-certs-default -o yaml | grep crt | awk '{print $2}' | base64 -d | openssl x509 -noout -dates -issuer -subject
```

`tls.crt` contains two certs

```text
-----BEGIN CERTIFICATE-----
MIIDWzCCAkOgAwIBAgIIUUg1fwtYuLYwDQYJKoZIhvcNAQELBQAwJjEkMCIGA1UE
AwwbaW5ncmVzcy1vcGVyYXRvckAxNzY0MTc1NDQzMB4XDTI1MTEyNjE2NDQwNFoX
DTI3MTEyNjE2NDQwNVowHTEbMBkGA1UEAwwSKi5hcHBzLWNyYy50ZXN0aW5nMIIB
IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA3p75e0Mtd0d+vvYDIs+RXQE6
2JuVVSf5XAfmCdijkiB8n0QAgsnJ1AgMAUxBdioXk4xJei4uo6hD7+mPDGlKNfb4
UXZDiIqCIedo0NiPBS+H9Ss4orQqHEpgQYtJxUvLBaCV4LvxF9W3/j7KB0PZbjU3
Ru4bvBG9ZupZ+yc0nz9zA+K0iB0GZJYhfs7RXd/E8iSX1exkGS0jTqUik4YviCfw
SRyPSPQzOiLpXrEl9DE0GOPrQG2aBXYXeYNrYIB8/+1WrcbB6Mv+clSN8DmxYVZW
cPrMfCY8576BWQNQ4mn5arwFqz53OPnPC7nv5N3swXTNC/et3GX1fklkCV1X7QID
AQABo4GVMIGSMA4GA1UdDwEB/wQEAwIFoDATBgNVHSUEDDAKBggrBgEFBQcDATAM
BgNVHRMBAf8EAjAAMB0GA1UdDgQWBBTFMKpPpjPzcnRDZk34CoTGiqr99zAfBgNV
HSMEGDAWgBT5z7cASeLoeEfxK0c6/v0hPjZ1GjAdBgNVHREEFjAUghIqLmFwcHMt
Y3JjLnRlc3RpbmcwDQYJKoZIhvcNAQELBQADggEBAGKOVA20Jp56+/gCfehXrZYB
VV2+685DPgBaSi8AxwSl0U6ZzeMaMUS0wOYcT5Ik7zSbM7ukk9Xe+aOKmRQ0XkRh
HrF2ZY7riygSVFyWrL2jCphDUOsa1xZcMo6gx44qSEw12GpyPSeWq18xT5n+NP45
8O5/w+NX5zeajhlCinpXnlSadUgEN3u//HxISUmkjNv2TOwcxhRgG3Oqf7fT50i0
tzy2yrdM7FyldbuoP2C+EwAX11QHTZD37qpHEVHPDjk6TLhOQuvW2A2/R4l1AdDl
I72762/ftsZJk6QuAJdwazopYfXMx/OuIYJHEOhJoOC3ctY+1JQBr65vTh7cRPo=
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIDDDCCAfSgAwIBAgIBATANBgkqhkiG9w0BAQsFADAmMSQwIgYDVQQDDBtpbmdy
ZXNzLW9wZXJhdG9yQDE3NjQxNzU0NDMwHhcNMjUxMTI2MTY0NDAyWhcNMjcxMTI2
MTY0NDAzWjAmMSQwIgYDVQQDDBtpbmdyZXNzLW9wZXJhdG9yQDE3NjQxNzU0NDMw
ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCnxkliyEEkKZaVTSPLWQ7G
lyMktQViMwEv1MyZyCmOglMSBt6S6X9ImJlb1P15a30MCZAl2NjYU8Vm4TATnHaf
zkWCyUWGsRTqkGFmnb/3xkGEyxx6GFbb99gKgIVlBd8CKaRaJJNMCf8+y7YXLDuG
aPYZozU8rdm1dZgBD68p/kRtAK13BhhIiRdmBBQaB80JAMNC9WyqFzSns9k9uVpL
0PIdO41c3budzuitbs5pwieAln1Blx3vZR2+w72NpOI2VzpB/j0AuSutrnPyI5QV
LfbiO0s0kWQRGxztMCSAzqkZkKGmohQVQ67JUSFIRBAz9sCcEYnCwIgl9Va+PfX7
AgMBAAGjRTBDMA4GA1UdDwEB/wQEAwICpDASBgNVHRMBAf8ECDAGAQH/AgEAMB0G
A1UdDgQWBBT5z7cASeLoeEfxK0c6/v0hPjZ1GjANBgkqhkiG9w0BAQsFAAOCAQEA
DgyFH5L/ytSDxIyLK0S9fn2h1uV30jH4Xzok8zIu0I/tDhxBYO6YoaYBd72bUUdD
Vydf/gtOOxDv6lR77NDBAXsPDQQ6tAqZxuTCrFkvpFrOqAuCYOUdadN+Oayxz58a
G6Ugt4RcXbqa9mjsLmR6JuyWBWaBst6fX1w6GxOuuKOqLsUywOfvSQjvL77d9s/o
WaFpmmEOPZV7VRq7TidHuGuV9mQ99zCJ0AVWW8L7AmazRPrtVzXnVUJjXSzWR3SK
Zk3KHoqwdGDPdPx01gCaSS1gMg+R3ah8lBiWtVfCVF2afGU0TIwjoes3RnsbIEYA
VAsPERWqJ9kLwejPCZbVgw==
-----END CERTIFICATE-----
```

Expected:

```text
notBefore=Nov 26 16:44:04 2025 GMT
notAfter=Nov 26 16:44:05 2027 GMT
issuer=CN=ingress-operator@1764175443
subject=CN=*.apps-crc.testing
```

Validate ingress CA.

```shell
oc project openshift-ingress-operator
oc get secret router-ca -oyaml | grep crt | awk '{print $2}' | base64 -d | openssl x509 -noout -dates -issuer -subject
```

`tls.crt` contains one cert.

```text
-----BEGIN CERTIFICATE-----
MIIDDDCCAfSgAwIBAgIBATANBgkqhkiG9w0BAQsFADAmMSQwIgYDVQQDDBtpbmdy
ZXNzLW9wZXJhdG9yQDE3NjQxNzU0NDMwHhcNMjUxMTI2MTY0NDAyWhcNMjcxMTI2
MTY0NDAzWjAmMSQwIgYDVQQDDBtpbmdyZXNzLW9wZXJhdG9yQDE3NjQxNzU0NDMw
ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCnxkliyEEkKZaVTSPLWQ7G
lyMktQViMwEv1MyZyCmOglMSBt6S6X9ImJlb1P15a30MCZAl2NjYU8Vm4TATnHaf
zkWCyUWGsRTqkGFmnb/3xkGEyxx6GFbb99gKgIVlBd8CKaRaJJNMCf8+y7YXLDuG
aPYZozU8rdm1dZgBD68p/kRtAK13BhhIiRdmBBQaB80JAMNC9WyqFzSns9k9uVpL
0PIdO41c3budzuitbs5pwieAln1Blx3vZR2+w72NpOI2VzpB/j0AuSutrnPyI5QV
LfbiO0s0kWQRGxztMCSAzqkZkKGmohQVQ67JUSFIRBAz9sCcEYnCwIgl9Va+PfX7
AgMBAAGjRTBDMA4GA1UdDwEB/wQEAwICpDASBgNVHRMBAf8ECDAGAQH/AgEAMB0G
A1UdDgQWBBT5z7cASeLoeEfxK0c6/v0hPjZ1GjANBgkqhkiG9w0BAQsFAAOCAQEA
DgyFH5L/ytSDxIyLK0S9fn2h1uV30jH4Xzok8zIu0I/tDhxBYO6YoaYBd72bUUdD
Vydf/gtOOxDv6lR77NDBAXsPDQQ6tAqZxuTCrFkvpFrOqAuCYOUdadN+Oayxz58a
G6Ugt4RcXbqa9mjsLmR6JuyWBWaBst6fX1w6GxOuuKOqLsUywOfvSQjvL77d9s/o
WaFpmmEOPZV7VRq7TidHuGuV9mQ99zCJ0AVWW8L7AmazRPrtVzXnVUJjXSzWR3SK
Zk3KHoqwdGDPdPx01gCaSS1gMg+R3ah8lBiWtVfCVF2afGU0TIwjoes3RnsbIEYA
VAsPERWqJ9kLwejPCZbVgw==
-----END CERTIFICATE-----
```

Expected:

```text
notBefore=Nov 26 16:44:02 2025 GMT
notAfter=Nov 26 16:44:03 2027 GMT
issuer=CN=ingress-operator@1764175443
subject=CN=ingress-operator@1764175443
```

Renew ingress CA.

```shell
oc project openshift-ingress-operator
oc get secret router-ca -oyaml > router-ca.yaml
oc delete secret router-ca
oc delete pod --all
oc get secret router-ca
oc get po
```

Re-create wildcard ingress certificate.

```shell
oc project openshift-ingress
oc get secret router-certs-default -o yaml > router-certs-default.yaml
oc delete secret router-certs-default
oc delete pod --all $ oc get secret router-certs-default
oc get po
```
