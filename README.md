# OpenShift CI/CD Test

This repo contains an example of how to configure application builds and deployments against an OpenShift cluster.
The example is intended to be run locally using OpenShift Local.

GitHub Actions is the primary CI/CD tool in use, but parallels will be drawn with GitLab Pipelines.

## Configuring the Cluster

The following subsections explain...

1. TODO

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
